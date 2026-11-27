module ImportHelpers
  HEADER = "社員番号,氏名,email,所属部署名\n".freeze

  def csv_with(*lines, header: HEADER)
    header + lines.map { |line| "#{line}\n" }.join
  end

  # tenant を渡すと、そのテナントの直接アップロードで作られたファイルと同じ状態にする
  def upload_blob(content, tenant: nil)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename: "employees.csv", content_type: "text/csv",
      metadata: tenant ? { tenant_id: tenant.id } : {}
    )
  end

  def create_tenant_with_departments(*names)
    tenant = Tenant.create!(name: "テスト株式会社")
    names.each { |name| tenant.departments.create!(name:) }
    tenant
  end
end

RSpec.configure { |config| config.include ImportHelpers }
