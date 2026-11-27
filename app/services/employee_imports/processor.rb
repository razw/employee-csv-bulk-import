module EmployeeImports
  # インポート 1 件を最後まで処理する。
  # 結果は「全件登録 (completed)」か「1 件も登録しない (invalid / failed)」のどちらかになる。
  class Processor
    INSERT_BATCH_SIZE = 5_000

    def self.call(import) = new(import).call

    def initialize(import)
      @import = import
    end

    def call
      # ジョブの再実行 (リトライ・二重投入) で同じ結果になるよう、終わったものは何もしない
      return if @import.finished?

      @import.update!(status: :processing, started_at: Time.current) if @import.status_pending?

      rows = @import.file.open { |file| CsvReader.read(file) }
      result = RowValidator.new(@import.tenant).validate(rows)

      if result.errors.empty?
        insert_employees(result.attributes)
      else
        record_errors(result.errors, total_rows: rows.size)
      end
    rescue CsvReader::FileError => e
      finish!(:invalid, failure_reason: e.message)
    rescue ActiveRecord::RecordNotUnique
      # 検証後に別の処理が同じ社員番号・email を登録した場合。前提上は起きないが、DB の一意制約で検知する
      finish!(:failed, failure_reason: "他の処理と登録内容が競合しました。もう一度アップロードしてください")
    end

    private

    # 全件を 1 トランザクションで登録し、ステータス更新も同じトランザクションに含める。
    # 途中で落ちてもロールバックされ、リトライ時は最初からやり直せる。
    def insert_employees(attributes)
      ApplicationRecord.transaction do
        attributes.each_slice(INSERT_BATCH_SIZE) do |batch|
          Employee.insert_all!(batch, returning: false)
        end
        finish!(:completed, total_rows: attributes.size, imported_count: attributes.size)
      end
    end

    def record_errors(errors, total_rows:)
      ApplicationRecord.transaction do
        errors.each_slice(INSERT_BATCH_SIZE) do |batch|
          EmployeeImportError.insert_all!(
            batch.map { |e| { employee_import_id: @import.id, row_number: e.row_number, column: e.column, message: e.message } },
            returning: false
          )
        end
        finish!(:invalid, total_rows:, error_count: errors.size)
      end
    end

    def finish!(status, **attributes)
      @import.update!(status:, finished_at: Time.current, **attributes)
    end
  end
end
