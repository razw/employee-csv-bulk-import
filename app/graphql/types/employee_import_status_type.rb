# frozen_string_literal: true

module Types
  class EmployeeImportStatusType < Types::BaseEnum
    value "PENDING", "受付済み、処理待ち", value: "pending"
    value "PROCESSING", "処理中", value: "processing"
    value "COMPLETED", "全件登録済み", value: "completed"
    value "INVALID", "入力エラーあり。1 件も登録していない", value: "invalid"
    value "FAILED", "システムエラー。1 件も登録していない", value: "failed"
  end
end
