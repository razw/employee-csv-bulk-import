require "rails_helper"

RSpec.describe EmployeeImports::Processor do
  let(:tenant) { create_tenant_with_departments("人事部", "開発部") }
  let(:user) { tenant.users.create!(name: "人事 太郎") }

  def create_import(content)
    tenant.employee_imports.create!(requested_by: user, file: upload_blob(content))
  end

  it "エラーが無ければ全件登録して completed にする" do
    import = create_import(csv_with("E001,山田,yamada@example.com,人事部", "E002,佐藤,sato@example.com,開発部"))

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "completed", total_rows: 2, imported_count: 2, error_count: 0)
    expect(tenant.employees.pluck(:employee_number)).to contain_exactly("E001", "E002")
  end

  it "1 行でもエラーがあれば 1 件も登録せず、エラーを保存して invalid にする" do
    import = create_import(csv_with("E001,山田,yamada@example.com,人事部", "E002,佐藤,sato@example.com,営業部"))

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "invalid", total_rows: 2, imported_count: 0, error_count: 1)
    expect(import.import_errors.pluck(:row_number, :column)).to eq [ [ 3, "所属部署名" ] ]
    expect(tenant.employees).to be_empty
  end

  it "ファイル全体の問題は failure_reason に理由を入れて invalid にする" do
    import = create_import("氏名\n山田\n")

    described_class.call(import)

    expect(import.reload).to have_attributes(status: "invalid", failure_reason: a_string_matching(/必須の列/))
  end

  it "完了済みのインポートを再実行しても二重登録しない" do
    import = create_import(csv_with("E001,山田,yamada@example.com,人事部"))
    described_class.call(import)

    expect { described_class.call(import.reload) }.not_to change(Employee, :count)
    expect(import.reload.status).to eq "completed"
  end

  it "同じインポートを 2 つのワーカーが同時に処理しても、先に終わった結果を上書きしない" do
    import = create_import(csv_with("E001,山田,yamada@example.com,人事部"))
    other_worker_done = false
    # 1 つ目のワーカーが検証を終えた直後に、2 つ目のワーカーが登録まで終える
    allow_any_instance_of(EmployeeImports::RowValidator).to receive(:validate).and_wrap_original do |original, *args|
      result = original.call(*args)
      unless other_worker_done
        other_worker_done = true
        described_class.call(EmployeeImport.find(import.id))
      end
      result
    end

    described_class.call(EmployeeImport.find(import.id))

    expect(import.reload).to have_attributes(status: "completed", imported_count: 1, failure_reason: nil)
    expect(tenant.employees.count).to eq 1
  end

  it "完了したインポートを後から来たワーカーが重複エラーで invalid にしない" do
    import = create_import(csv_with("E001,山田,yamada@example.com,人事部"))
    stale = EmployeeImport.find(import.id) # 完了前に読み込んだ状態のまま処理を始めるワーカー

    described_class.call(import)
    described_class.call(stale)

    expect(import.reload).to have_attributes(status: "completed", error_count: 0)
    expect(import.import_errors).to be_empty
  end

  it "登録の途中で失敗したら全件ロールバックし、再実行で最初からやり直せる" do
    stub_const("#{described_class}::INSERT_BATCH_SIZE", 1)
    import = create_import(csv_with("E001,山田,yamada@example.com,人事部", "E002,佐藤,sato@example.com,開発部"))
    calls = 0
    allow(Employee).to receive(:insert_all!).and_wrap_original do |original, *args, **kwargs|
      calls += 1
      raise ActiveRecord::ConnectionFailed, "接続断" if calls == 2
      original.call(*args, **kwargs)
    end

    expect { described_class.call(import) }.to raise_error(ActiveRecord::ConnectionFailed)
    expect(tenant.employees).to be_empty
    expect(import.reload.status).to eq "processing"

    calls = -1 # 2 回目以降は失敗させない
    described_class.call(import)

    expect(import.reload.status).to eq "completed"
    expect(tenant.employees.count).to eq 2
  end
end
