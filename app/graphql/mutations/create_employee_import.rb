# frozen_string_literal: true

module Mutations
  # アップロード済みファイルの取り込みを受け付け、ジョブに渡してすぐ返す。
  # 処理本体は非同期なので、5 万行でもレスポンスは 1 分のタイムアウトに収まる。
  class CreateEmployeeImport < BaseMutation
    argument :signed_blob_id, String, required: true

    field :employee_import, Types::EmployeeImportType, null: true
    field :errors, [ Types::UserErrorType ], null: false

    def resolve(signed_blob_id:)
      user = context[:current_user]
      blob = ActiveStorage::Blob.find_signed(signed_blob_id)
      return failure("ファイルが見つかりません。もう一度アップロードしてください") if blob.nil?
      return failure("ファイルサイズの上限を超えています") if blob.byte_size > EmployeeImport::MAX_FILE_SIZE

      import = user.tenant.employee_imports.create!(requested_by: user, file: blob)
      EmployeeImportJob.perform_later(import.id)
      { employee_import: import, errors: [] }
    rescue ActiveRecord::RecordNotUnique
      # 部分ユニークインデックスにより、同じテナントで実行中のインポートは 1 件まで
      failure("実行中のインポートがあります。完了してから再度お試しください")
    end

    private

    def failure(message) = { employee_import: nil, errors: [ { message: } ] }
  end
end
