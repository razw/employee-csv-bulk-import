class EmployeeImportJob < ApplicationJob
  queue_as :imports

  # DB の一時的な障害などは時間をおいて再実行する。
  # 処理は冪等 (全件登録とステータス更新が 1 トランザクション) なので、再実行しても二重登録にならない。
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    import = EmployeeImport.find(job.arguments.first)
    import.with_lock do
      # 別のワーカーが先に終えていれば、その結果を残す
      import.update!(status: :failed, finished_at: Time.current, failure_reason: "システムエラーが発生しました") unless import.finished?
    end
    Rails.error.report(error, context: { employee_import_id: import.id })
  end

  def perform(employee_import_id)
    EmployeeImports::Processor.call(EmployeeImport.find(employee_import_id))
  end
end
