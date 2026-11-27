# frozen_string_literal: true

module Types
  class EmployeeImportErrorType < Types::BaseObject
    field :row_number, Integer, null: false, description: "CSV 上の行番号 (ヘッダーが 1 行目)"
    field :column, String, null: true, description: "エラーのある列名"
    field :message, String, null: false
  end
end
