require "csv"

module EmployeeImports
  # アップロードされたバイト列を、検証前の行データに変換する。
  # ファイル全体を受け付けられない問題 (文字コード・ヘッダー・行数) は FileError で返す。
  class CsvReader
    MAX_ROWS = 50_000
    UTF8_BOM = "\xEF\xBB\xBF".b

    # CSV の列名と、行データのキーの対応
    HEADERS = {
      "社員番号" => :employee_number,
      "氏名" => :name,
      "email" => :email,
      "所属部署名" => :department_name
    }.freeze

    # row_number はファイル上の行番号 (ヘッダーが 1 行目)。Excel で開いたときの行番号と一致する。
    Row = Data.define(:row_number, :employee_number, :name, :email, :department_name)

    class FileError < StandardError; end

    def self.read(io) = new.read(io)

    def read(io)
      text = decode(io.read)
      table = parse(text)
      header_index = build_header_index(table.shift)
      raise FileError, "データ行がありません" if table.empty?
      raise FileError, "行数が上限 (#{MAX_ROWS} 行) を超えています: #{table.size} 行" if table.size > MAX_ROWS

      table.each_with_index.filter_map do |fields, i|
        next if fields.all? { |f| f.to_s.strip.empty? } # Excel が末尾に出す空行は無視する

        values = header_index.transform_values { |index| fields[index] }
        Row.new(row_number: i + 2, **values)
      end
    end

    private

    # Excel から保存した CSV は Shift_JIS (CP932) のことが多い。
    # UTF-8 として正しく読めればそのまま使い、読めなければ CP932 として変換する。
    def decode(bytes)
      bytes = bytes.b
      bytes = bytes.byteslice(UTF8_BOM.bytesize..) if bytes.start_with?(UTF8_BOM)

      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      return utf8 if utf8.valid_encoding?

      bytes.encode(Encoding::UTF_8, Encoding::CP932)
    rescue EncodingError
      raise FileError, "文字コードを判別できません。UTF-8 または Shift_JIS で保存してください"
    end

    def parse(text)
      CSV.parse(text)
    rescue CSV::MalformedCSVError => e
      raise FileError, "CSV の形式が正しくありません (#{e.message})"
    end

    def build_header_index(header_row)
      raise FileError, "ファイルが空です" if header_row.nil?

      normalized = header_row.map { |h| normalize_header(h) }
      HEADERS.to_h do |label, key|
        indexes = normalized.each_index.select { |i| normalized[i] == normalize_header(label) }
        raise FileError, "必須の列がありません: #{label}" if indexes.empty?
        raise FileError, "列名が重複しています: #{label}" if indexes.size > 1

        [ key, indexes.first ]
      end
    end

    def normalize_header(value)
      value.to_s.unicode_normalize(:nfkc).strip.downcase
    end
  end
end
