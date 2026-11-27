require "rails_helper"

RSpec.describe EmployeeImports::RowValidator do
  let(:tenant) { create_tenant_with_departments("人事部", "開発部") }

  def validate(*lines)
    rows = EmployeeImports::CsvReader.read(StringIO.new(csv_with(*lines)))
    described_class.new(tenant).validate(rows)
  end

  def error_messages(result) = result.errors.map { |e| [ e.row_number, e.column, e.message ] }

  it "正しい行は登録用の属性に変換する" do
    result = validate("E001,山田 太郎,yamada@example.com,人事部")

    expect(result.errors).to be_empty
    expect(result.attributes.first).to include(
      tenant_id: tenant.id, employee_number: "E001", name: "山田 太郎", email: "yamada@example.com",
      department_id: tenant.departments.find_by!(name: "人事部").id
    )
  end

  it "全角英数字・前後の空白・email の大文字を正規化する" do
    result = validate("Ｅ００１ , 山田 太郎 , Yamada＠Example.com ,  人事部 ")

    expect(result.errors).to be_empty
    expect(result.attributes.first).to include(employee_number: "E001", name: "山田 太郎", email: "yamada@example.com")
  end

  it "必須項目の欠落を列ごとに返す" do
    result = validate("E001,,,", ",山田,,")

    expect(error_messages(result)).to contain_exactly(
      [ 2, "氏名", "必須です" ], [ 2, "email", "必須です" ], [ 2, "所属部署名", "必須です" ],
      [ 3, "社員番号", "必須です" ], [ 3, "email", "必須です" ], [ 3, "所属部署名", "必須です" ]
    )
  end

  it "形式の誤りを返す" do
    result = validate("E-001/x,山田,not-an-email,人事部")

    expect(error_messages(result)).to contain_exactly(
      [ 2, "社員番号", a_string_matching(/半角英数字/) ], [ 2, "email", "形式が正しくありません" ]
    )
  end

  it "存在しない部署はエラーにする (自動作成しない)" do
    result = validate("E001,山田,yamada@example.com,営業部")

    expect(error_messages(result)).to eq [ [ 2, "所属部署名", "存在しない部署です: 営業部" ] ]
  end

  it "正規化すると同じ名前になる部署が複数あれば、どちらか決められないのでエラーにする" do
    tenant.departments.create!(name: "営業１部")
    tenant.departments.create!(name: "営業1部")

    result = validate("E001,山田,yamada@example.com,営業1部")

    expect(error_messages(result)).to eq [ [ 2, "所属部署名", "同じ名前とみなされる部署が複数あります: 営業1部" ] ]
  end

  it "CSV 内で重複した社員番号・email は後の行をエラーにする" do
    result = validate(
      "E001,山田,yamada@example.com,人事部",
      "E001,佐藤,sato@example.com,人事部",
      "E003,鈴木,YAMADA@example.com,人事部"
    )

    expect(error_messages(result)).to contain_exactly(
      [ 3, "社員番号", "2 行目と重複しています" ], [ 4, "email", "2 行目と重複しています" ]
    )
  end

  it "既に登録済みの社員番号・email はエラーにする" do
    tenant.employees.create!(department: tenant.departments.first, employee_number: "E001", name: "既存", email: "exists@example.com")

    result = validate("E001,山田,yamada@example.com,人事部", "E002,佐藤,exists@example.com,人事部")

    expect(error_messages(result)).to contain_exactly(
      [ 2, "社員番号", "既に登録されています" ], [ 3, "email", "既に登録されています" ]
    )
  end

  it "他テナントの社員とは重複しない" do
    other = create_tenant_with_departments("人事部")
    other.employees.create!(department: other.departments.first, employee_number: "E001", name: "他社", email: "yamada@example.com")

    expect(validate("E001,山田,yamada@example.com,人事部").errors).to be_empty
  end
end
