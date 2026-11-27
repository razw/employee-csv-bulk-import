# frozen_string_literal: true

module Mutations
  # ファイル本体はアプリサーバーを経由させず、署名付き URL でストレージ (本番は S3) に直接送る。
  # 大きなファイルの転送でリクエストが 1 分を超えるのを避けるため。
  class CreateDirectUpload < BaseMutation
    description "CSV をストレージ (本番は S3) へ直接アップロードするための URL を発行する。ファイル本体は API サーバーを通さない"

    argument :filename, String, required: true, description: "ファイル名"
    argument :byte_size, Integer, required: true, description: "ファイルサイズ (バイト)。上限は 10MB"
    argument :checksum, String, required: true, description: "ファイルの MD5 (Base64)"
    argument :content_type, String, required: true, description: "ファイルの MIME タイプ (例: text/csv)"

    field :url, String, null: true, description: "ファイル本体を PUT する URL。errors があれば null"
    field :headers, GraphQL::Types::JSON, null: true, description: "url への PUT に付ける HTTP ヘッダー"
    field :signed_blob_id, String, null: true, description: "アップロード後に createEmployeeImport へ渡す ID"
    field :errors, [ Types::UserErrorType ], null: false, description: "入力エラー。空なら成功"

    def resolve(filename:, byte_size:, checksum:, content_type:)
      if byte_size > EmployeeImport::MAX_FILE_SIZE
        return { errors: [ { message: "ファイルサイズの上限は #{EmployeeImport::MAX_FILE_SIZE / 1.megabyte}MB です" } ] }
      end

      # どのテナントがアップロードしたかを記録し、インポート受付時に照合する
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename:, byte_size:, checksum:, content_type:,
        metadata: { tenant_id: context[:current_user].tenant_id }
      )
      {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload,
        signed_blob_id: blob.signed_id,
        errors: []
      }
    end
  end
end
