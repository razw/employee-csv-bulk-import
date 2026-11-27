# frozen_string_literal: true

module Types
  class EmployeeImportType < Types::BaseObject
    field :id, ID, null: false
    field :status, Types::EmployeeImportStatusType, null: false
    field :total_rows, Integer, null: true
    field :imported_count, Integer, null: false
    field :error_count, Integer, null: false
    field :failure_reason, String, null: true, description: "ファイル全体を受け付けられなかった理由 (文字コード・ヘッダーなど)"
    field :started_at, GraphQL::Types::ISO8601DateTime, null: true
    field :finished_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :import_errors, Types::EmployeeImportErrorType.connection_type, null: false,
      description: "行ごとのエラー。件数が多くなりうるためページングする", max_page_size: 1_000
  end
end
