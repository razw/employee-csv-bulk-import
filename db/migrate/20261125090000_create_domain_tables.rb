class CreateDomainTables < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.timestamps
    end

    # 人事担当者など、この機能を操作するユーザー
    create_table :users do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :departments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
      t.index %i[tenant_id name], unique: true
    end

    create_table :employees do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.string :employee_number, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps
      # アプリ側の重複チェックをすり抜けた場合の最後の砦
      t.index %i[tenant_id employee_number], unique: true
      t.index %i[tenant_id email], unique: true
    end

    create_table :employee_imports do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.integer :total_rows
      t.integer :imported_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.string :failure_reason
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
      # 同一テナントで実行中のインポートは 1 件まで (DB で保証する)
      t.index :tenant_id, unique: true, where: "status IN ('pending', 'processing')",
                          name: "index_employee_imports_one_active_per_tenant"
    end

    create_table :employee_import_errors do |t|
      t.references :employee_import, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :row_number, null: false
      t.string :column
      t.string :message, null: false
      t.index %i[employee_import_id row_number]
    end
  end
end
