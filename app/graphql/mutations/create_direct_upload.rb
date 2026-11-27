# frozen_string_literal: true

module Mutations
  # ファイル本体はアプリサーバーを経由させず、署名付き URL でストレージ (本番は S3) に直接送る。
  # 大きなファイルの転送でリクエストが 1 分を超えるのを避けるため。
  class CreateDirectUpload < BaseMutation
    argument :filename, String, required: true
    argument :byte_size, Integer, required: true
    argument :checksum, String, required: true, description: "ファイルの MD5 (Base64)"
    argument :content_type, String, required: true

    field :url, String, null: true
    field :headers, GraphQL::Types::JSON, null: true, description: "アップロード時に付ける HTTP ヘッダー"
    field :signed_blob_id, String, null: true
    field :errors, [ Types::UserErrorType ], null: false

    def resolve(filename:, byte_size:, checksum:, content_type:)
      if byte_size > EmployeeImport::MAX_FILE_SIZE
        return { errors: [ { message: "ファイルサイズの上限は #{EmployeeImport::MAX_FILE_SIZE / 1.megabyte}MB です" } ] }
      end

      blob = ActiveStorage::Blob.create_before_direct_upload!(filename:, byte_size:, checksum:, content_type:)
      {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload,
        signed_blob_id: blob.signed_id,
        errors: []
      }
    end
  end
end
