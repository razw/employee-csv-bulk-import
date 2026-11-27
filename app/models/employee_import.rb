class EmployeeImport < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes
  ACCEPTED_CONTENT_TYPES = %w[text/csv application/vnd.ms-excel text/plain].freeze

  # pending    : 受付済み、ジョブ待ち
  # processing : ジョブ実行中
  # completed  : 全件登録済み
  # invalid    : 入力エラーあり。1 件も登録していない
  # failed     : システムエラー。1 件も登録していない
  enum :status, {
    pending: "pending", processing: "processing", completed: "completed",
    invalid: "invalid", failed: "failed"
  }, prefix: true

  belongs_to :tenant
  belongs_to :requested_by, class_name: "User"
  has_many :import_errors, -> { order(:row_number, :id) }, class_name: "EmployeeImportError"
  has_one_attached :file

  def finished?
    status_completed? || status_invalid? || status_failed?
  end
end
