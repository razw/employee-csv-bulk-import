# frozen_string_literal: true

module Types
  class EmployeeImportErrorType < Types::BaseObject
    description "CSV の 1 行・1 列についてのエラー"

    field :row_number, Integer, null: false, description: "CSV 上の行番号 (ヘッダーが 1 行目)"
    field :column, String, null: true, description: "エラーのある列名 (CSV のヘッダーの名前)"
    field :message, String, null: false, description: "利用者に見せるエラーの理由"
  end
end
