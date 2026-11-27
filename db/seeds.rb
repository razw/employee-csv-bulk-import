# 開発・デモ用のデータ
tenant = Tenant.find_or_create_by!(name: "サンプル株式会社")
User.find_or_create_by!(tenant:, name: "人事 太郎")

DEPARTMENT_NAMES = %w[人事部 総務部 経理部 法務部 営業部 開発部 品質保証部 製造部 物流部 マーケティング部].freeze
DEPARTMENT_NAMES.each { |name| Department.find_or_create_by!(tenant:, name:) }
