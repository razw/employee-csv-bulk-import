require "rails_helper"

RSpec.describe EmployeeImports::CsvReader do
  def read(content) = described_class.read(StringIO.new(content))

  it "行番号をファイル上の行番号 (ヘッダーが 1 行目) で返す" do
    rows = read(csv_with("E001,山田 太郎,yamada@example.com,人事部", "E002,佐藤 花子,sato@example.com,開発部"))

    expect(rows.map(&:row_number)).to eq [ 2, 3 ]
    expect(rows.first).to have_attributes(employee_number: "E001", name: "山田 太郎", email: "yamada@example.com", department_name: "人事部")
  end

  it "列の順番が違っても列名で判定する" do
    rows = read(csv_with("yamada@example.com,人事部,E001,山田 太郎", header: "email,所属部署名,社員番号,氏名\n"))

    expect(rows.first).to have_attributes(employee_number: "E001", department_name: "人事部")
  end

  it "BOM 付き UTF-8 を読める" do
    rows = read("﻿" + csv_with("E001,山田 太郎,yamada@example.com,人事部"))

    expect(rows.first.employee_number).to eq "E001"
  end

  it "Excel で保存した Shift_JIS (CP932) を読める" do
    rows = read(csv_with("E001,髙橋 一郎,takahashi@example.com,人事部").encode(Encoding::CP932))

    expect(rows.first).to have_attributes(name: "髙橋 一郎", department_name: "人事部")
  end

  it "末尾の空行は無視する" do
    rows = read(csv_with("E001,山田 太郎,yamada@example.com,人事部", ",,,", ""))

    expect(rows.size).to eq 1
  end

  it "必須の列が無いとファイル全体をエラーにする" do
    expect { read("社員番号,氏名,email\nE001,山田,y@example.com\n") }
      .to raise_error(described_class::FileError, /必須の列がありません: 所属部署名/)
  end

  it "データ行が無いとエラーにする" do
    expect { read(ImportHelpers::HEADER) }.to raise_error(described_class::FileError, /データ行がありません/)
  end

  it "行数が上限を超えるとエラーにする" do
    stub_const("#{described_class}::MAX_ROWS", 2)

    expect { read(csv_with("1,a,a@example.com,人事部", "2,b,b@example.com,人事部", "3,c,c@example.com,人事部")) }
      .to raise_error(described_class::FileError, /上限/)
  end

  it "UTF-8 でも Shift_JIS でもないバイト列はエラーにする" do
    expect { read(ImportHelpers::HEADER + "\x81\x00\xFF\xFE\n") }
      .to raise_error(described_class::FileError, /文字コード/)
  end
end
