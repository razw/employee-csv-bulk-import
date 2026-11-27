require "rails_helper"

RSpec.describe "社員 CSV インポート API", type: :request do
  let(:tenant) { create_tenant_with_departments("人事部") }
  let(:user) { tenant.users.create!(name: "人事 太郎") }

  # 変数は Hash でもキーワード引数でも渡せる
  def graphql(query, variables = nil, as: user, **keyword_variables)
    variables ||= keyword_variables
    post "/graphql", params: { query:, variables: }.to_json,
                     headers: { "Content-Type" => "application/json", "X-User-Id" => as&.id.to_s }
    response.parsed_body
  end

  CREATE_DIRECT_UPLOAD = <<~GQL
    mutation($input: CreateDirectUploadInput!) {
      createDirectUpload(input: $input) { url headers signedBlobId errors { message } }
    }
  GQL

  CREATE_IMPORT = <<~GQL
    mutation($signedBlobId: String!) {
      createEmployeeImport(input: { signedBlobId: $signedBlobId }) {
        employeeImport { id status }
        errors { message }
      }
    }
  GQL

  SHOW_IMPORT = <<~GQL
    query($id: ID!) {
      employeeImport(id: $id) {
        status totalRows importedCount errorCount failureReason
        importErrors(first: 10) { nodes { rowNumber column message } }
      }
    }
  GQL

  it "直接アップロード → インポート受付 → ジョブ実行 → 結果確認 の一連の流れが動く" do
    content = csv_with("E001,山田,yamada@example.com,人事部")
    upload = graphql(CREATE_DIRECT_UPLOAD, { input: {
      filename: "employees.csv", byteSize: content.bytesize,
      checksum: OpenSSL::Digest::MD5.base64digest(content), contentType: "text/csv"
    } }).dig("data", "createDirectUpload")
    expect(upload["errors"]).to be_empty

    # ブラウザが行う、ストレージへの直接 PUT
    put URI(upload["url"]).path, params: content, headers: upload["headers"]
    expect(response).to have_http_status(:no_content)

    created = graphql(CREATE_IMPORT, signedBlobId: upload["signedBlobId"]).dig("data", "createEmployeeImport")
    expect(created["employeeImport"]["status"]).to eq "PENDING"
    expect(EmployeeImportJob).to have_been_enqueued.with(created["employeeImport"]["id"].to_i)

    perform_enqueued_jobs

    result = graphql(SHOW_IMPORT, { id: created["employeeImport"]["id"] }).dig("data", "employeeImport")
    expect(result).to include("status" => "COMPLETED", "totalRows" => 1, "importedCount" => 1)
  end

  it "行エラーは行番号・列・理由で返す" do
    blob = upload_blob(csv_with("E001,山田,yamada@example.com,営業部"), tenant:)
    id = graphql(CREATE_IMPORT, signedBlobId: blob.signed_id).dig("data", "createEmployeeImport", "employeeImport", "id")
    perform_enqueued_jobs

    result = graphql(SHOW_IMPORT, id:).dig("data", "employeeImport")

    expect(result).to include("status" => "INVALID", "errorCount" => 1, "importedCount" => 0)
    expect(result["importErrors"]["nodes"]).to eq [ { "rowNumber" => 2, "column" => "所属部署名", "message" => "存在しない部署です: 営業部" } ]
  end

  it "同じテナントで実行中のインポートがあれば受け付けない" do
    graphql(CREATE_IMPORT, signedBlobId: upload_blob(csv_with("E001,山田,yamada@example.com,人事部"), tenant:).signed_id)

    second = graphql(CREATE_IMPORT, signedBlobId: upload_blob(csv_with("E002,佐藤,sato@example.com,人事部"), tenant:).signed_id)

    expect(second.dig("data", "createEmployeeImport", "errors")).to eq [ { "message" => "実行中のインポートがあります。完了してから再度お試しください" } ]
  end

  it "上限を超えるファイルサイズはアップロード前に断る" do
    result = graphql(CREATE_DIRECT_UPLOAD, { input: {
      filename: "big.csv", byteSize: EmployeeImport::MAX_FILE_SIZE + 1, checksum: "x", contentType: "text/csv"
    } }).dig("data", "createDirectUpload")

    expect(result["errors"].first["message"]).to match(/上限/)
    expect(result["url"]).to be_nil
  end

  it "他テナントでアップロードされたファイルは取り込めない" do
    other_tenant = create_tenant_with_departments("人事部")
    blob = upload_blob(csv_with("E001,山田,yamada@example.com,人事部"), tenant: other_tenant)

    result = graphql(CREATE_IMPORT, signedBlobId: blob.signed_id).dig("data", "createEmployeeImport")

    expect(result["errors"]).to eq [ { "message" => "ファイルが見つかりません。もう一度アップロードしてください" } ]
    expect(tenant.employee_imports).to be_empty
  end

  it "ファイル本体のアップロードが済んでいなければ受け付けない" do
    content = csv_with("E001,山田,yamada@example.com,人事部")
    upload = graphql(CREATE_DIRECT_UPLOAD, { input: {
      filename: "employees.csv", byteSize: content.bytesize,
      checksum: OpenSSL::Digest::MD5.base64digest(content), contentType: "text/csv"
    } }).dig("data", "createDirectUpload")

    result = graphql(CREATE_IMPORT, signedBlobId: upload["signedBlobId"]).dig("data", "createEmployeeImport")

    expect(result["errors"]).to eq [ { "message" => "ファイルのアップロードが完了していません。もう一度アップロードしてください" } ]
    expect(tenant.employee_imports).to be_empty
    expect(EmployeeImportJob).not_to have_been_enqueued
  end

  it "他テナントのインポートは参照できない" do
    import = tenant.employee_imports.create!(requested_by: user, file: upload_blob("x"))
    other_user = create_tenant_with_departments.users.create!(name: "他社ユーザー")

    expect(graphql(SHOW_IMPORT, { id: import.id }, as: other_user).dig("data", "employeeImport")).to be_nil
  end

  it "未認証のリクエストは拒否する" do
    graphql(SHOW_IMPORT, { id: 1 }, as: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
