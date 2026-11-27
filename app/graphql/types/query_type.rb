# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :employee_import, Types::EmployeeImportType, null: true,
      description: "インポートの進捗と結果。フロントはこれを数秒おきに polling する" do
      argument :id, ID, required: true
    end

    # 他テナントのインポートは見えないよう、必ずログインユーザーのテナントで絞る
    def employee_import(id:)
      context[:current_user].tenant.employee_imports.find_by(id:)
    end
  end
end
