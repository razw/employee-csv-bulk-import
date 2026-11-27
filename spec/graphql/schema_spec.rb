require "rails_helper"

RSpec.describe EmployeeCsvBulkImportSchema do
  # schema.graphql はフロントエンドが型の生成に使う API 仕様書。実装とずれたら CI で気づけるようにする
  it "schema.graphql が実装と一致している (違えば bin/rails graphql:dump_schema で更新する)" do
    expect(Rails.root.join("schema.graphql").read).to eq described_class.to_definition
  end
end
