# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :employee_import, Types::EmployeeImportType, null: true,
      description: "インポートの進捗と結果。終了 (COMPLETED / INVALID / FAILED) するまで数秒おきに取得する。自分のテナントのインポートでなければ null" do
      argument :id, ID, required: true, description: "createEmployeeImport で返ったインポートの ID"
    end

    # 他テナントのインポートは見えないよう、必ずログインユーザーのテナントで絞る
    def employee_import(id:)
      context[:current_user].tenant.employee_imports.find_by(id:)
    end
  end
end
