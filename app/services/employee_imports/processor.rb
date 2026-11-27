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
      # ジョブの再実行 (リトライ・二重投入) で同じ結果になるよう、終わったものは何もしない。
      # 手元の状態は古いことがあるため、ロックして最新の状態を読んでから判定する
      @import.with_lock do
        @import.update!(status: :processing, started_at: Time.current) if @import.status_pending?
      end
      return if @import.finished?

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
      # 検証後に他の経路で同じ社員番号・email が登録された場合。前提で除外されているのは参照・更新・削除で、
      # 新規登録は起こりうるため、最終的な一意性は DB の一意制約で保証する
      finish!(:failed, failure_reason: "他の処理と登録内容が競合しました。もう一度アップロードしてください")
    end

    private

    # 全件を 1 トランザクションで登録し、ステータス更新も同じトランザクションに含める。
    # 途中で落ちてもロールバックされ、リトライ時は最初からやり直せる。
    def insert_employees(attributes)
      finish!(:completed, total_rows: attributes.size, imported_count: attributes.size) do
        attributes.each_slice(INSERT_BATCH_SIZE) do |batch|
          Employee.insert_all!(batch, returning: false)
        end
      end
    end

    def record_errors(errors, total_rows:)
      finish!(:invalid, total_rows:, error_count: errors.size) do
        errors.each_slice(INSERT_BATCH_SIZE) do |batch|
          EmployeeImportError.insert_all!(
            batch.map { |e| { employee_import_id: @import.id, row_number: e.row_number, column: e.column, message: e.message } },
            returning: false
          )
        end
      end
    end

    # 結果の書き込みは、インポートの行をロックしてから行う。
    # Sidekiq は同じジョブを二重に実行しうるため、別のワーカーが先に終えていたら何もしない。
    # こうしないと、後から来たワーカーが「登録済み」の重複エラーで completed を上書きしてしまう。
    def finish!(status, **attributes)
      ApplicationRecord.transaction do
        @import.lock!
        next if @import.finished?

        yield if block_given?
        @import.update!(status:, finished_at: Time.current, **attributes)
      end
    end
  end
end
