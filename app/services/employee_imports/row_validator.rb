module EmployeeImports
  # 行データを検証・正規化し、登録できる属性か、行ごとのエラーを返す。
  # 1 行ずつ DB に問い合わせると 5 万行で 5 万回以上のクエリになるため、
  # 部署と既存社員はまとめて読み込み、Hash / Set で照合する。
  class RowValidator
    EMPLOYEE_NUMBER_FORMAT = /\A[A-Za-z0-9_-]{1,20}\z/
    NAME_MAX_LENGTH = 100
    EMAIL_MAX_LENGTH = 254
    LOOKUP_BATCH_SIZE = 5_000

    Error = Data.define(:row_number, :column, :message)
    Result = Data.define(:attributes, :errors)

    def self.normalize_department_name(name)
      name.to_s.unicode_normalize(:nfkc).strip
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def validate(rows)
      rows = rows.map { |row| normalize(row) }
      context = load_context(rows)
      first_seen_number = {}
      first_seen_email = {}
      attributes = []
      errors = []

      rows.each do |row|
        row_errors = validate_fields(row, context)
        row_errors.concat(check_duplicate_in_file(row, :employee_number, "社員番号", first_seen_number))
        row_errors.concat(check_duplicate_in_file(row, :email, "email", first_seen_email))

        if row_errors.empty?
          attributes << {
            tenant_id: @tenant.id,
            department_id: context[:department_ids].fetch(row.department_name),
            employee_number: row.employee_number,
            name: row.name,
            email: row.email
          }
        else
          errors.concat(row_errors)
        end
      end

      Result.new(attributes:, errors:)
    end

    private

    # Excel 由来の表記ゆれ (全角英数字・前後の空白・大文字の email) を吸収する
    def normalize(row)
      row.with(
        employee_number: row.employee_number.to_s.unicode_normalize(:nfkc).strip,
        name: row.name.to_s.strip,
        email: row.email.to_s.unicode_normalize(:nfkc).strip.downcase,
        department_name: self.class.normalize_department_name(row.department_name)
      )
    end

    def load_context(rows)
      department_ids = @tenant.departments.pluck(:name, :id)
                              .to_h { |name, id| [ self.class.normalize_department_name(name), id ] }
      {
        department_ids:,
        existing_numbers: existing_values(:employee_number, rows.map(&:employee_number)),
        existing_emails: existing_values(:email, rows.map(&:email))
      }
    end

    # テナントの全社員ではなく、CSV に出てくる値だけを IN 句で分割して問い合わせる
    def existing_values(column, values)
      values.uniq.each_slice(LOOKUP_BATCH_SIZE).each_with_object(Set.new) do |batch, found|
        found.merge(@tenant.employees.where(column => batch).pluck(column))
      end
    end

    def validate_fields(row, context)
      errors = []
      add = ->(column, message) { errors << Error.new(row_number: row.row_number, column:, message:) }

      if row.employee_number.empty?
        add.("社員番号", "必須です")
      elsif !row.employee_number.match?(EMPLOYEE_NUMBER_FORMAT)
        add.("社員番号", "半角英数字・ハイフン・アンダースコアの 20 文字以内で入力してください")
      elsif context[:existing_numbers].include?(row.employee_number)
        add.("社員番号", "既に登録されています")
      end

      if row.name.empty?
        add.("氏名", "必須です")
      elsif row.name.length > NAME_MAX_LENGTH
        add.("氏名", "#{NAME_MAX_LENGTH} 文字以内で入力してください")
      end

      if row.email.empty?
        add.("email", "必須です")
      elsif row.email.length > EMAIL_MAX_LENGTH || !row.email.match?(URI::MailTo::EMAIL_REGEXP)
        add.("email", "形式が正しくありません")
      elsif context[:existing_emails].include?(row.email)
        add.("email", "既に登録されています")
      end

      if row.department_name.empty?
        add.("所属部署名", "必須です")
      elsif !context[:department_ids].key?(row.department_name)
        add.("所属部署名", "存在しない部署です: #{row.department_name}")
      end

      errors
    end

    def check_duplicate_in_file(row, key, column, first_seen)
      value = row.public_send(key)
      return [] if value.empty?

      if (first_row = first_seen[value])
        [ Error.new(row_number: row.row_number, column:, message: "#{first_row} 行目と重複しています") ]
      else
        first_seen[value] = row.row_number
        []
      end
    end
  end
end
