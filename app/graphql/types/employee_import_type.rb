# frozen_string_literal: true

module Types
  class EmployeeImportType < Types::BaseObject
    description "社員 CSV のインポート 1 件。結果は全件登録 (COMPLETED) か、1 件も登録しない (INVALID / FAILED) のどちらかになる"

    field :id, ID, null: false, description: "インポートの ID"
    field :status, Types::EmployeeImportStatusType, null: false,
      description: "処理の状態。COMPLETED / INVALID / FAILED になったら終了で、それ以降は変わらない"
    field :total_rows, Integer, null: true,
      description: "CSV のデータ行数 (ヘッダーを除く)。処理が終わるまでと、failureReason のある終わり方をした場合は null"
    field :imported_count, Integer, null: false,
      description: "登録した社員の数。COMPLETED では totalRows と同じ値、それ以外は 0"
    field :error_count, Integer, null: false,
      description: "行エラーの件数。1 行の複数の列にエラーがあれば別々に数えるため、行数より多くなることがある"
    field :failure_reason, String, null: true,
      description: "ファイル全体を取り込めなかった理由。INVALID でファイル自体に問題がある場合 (文字コード・必須の列・行数の上限など) と、FAILED の場合に入る。" \
                   "行ごとのエラーは importErrors で返し、そのときこの項目は null"
    field :started_at, GraphQL::Types::ISO8601DateTime, null: true, description: "ジョブが処理を始めた日時"
    field :finished_at, GraphQL::Types::ISO8601DateTime, null: true, description: "処理が終わった日時"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "インポートを受け付けた日時"
    field :import_errors, Types::EmployeeImportErrorType.connection_type, null: false,
      description: "行ごとのエラー (行番号順)。1 ページは最大 1,000 件のため、多いときは pageInfo で次のページを取る", max_page_size: 1_000
  end
end
