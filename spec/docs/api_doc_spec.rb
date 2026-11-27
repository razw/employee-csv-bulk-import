require "rails_helper"

RSpec.describe "docs/api.md" do
  # フロントエンドが写して使う例なので、スキーマの変更で動かなくなったら CI で気づけるようにする
  it "載せている GraphQL の例がすべてスキーマに対して正しい" do
    examples = Rails.root.join("docs/api.md").read.scan(/```graphql\n(.*?)```/m).flatten

    expect(examples).not_to be_empty
    examples.each do |example|
      errors = EmployeeCsvBulkImportSchema.validate(example).map(&:message)
      expect(errors).to be_empty, "#{example}\n#{errors.join("\n")}"
    end
  end
end
