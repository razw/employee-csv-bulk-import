# 5 万行の CSV を生成し、インポート処理の各段階にかかる時間 (または使うメモリ) を計測する。
#   bin/rails runner script/benchmark_import.rb [行数] [--naive] [--memory]
# --naive を付けると、比較用に「1 行ずつ ActiveRecord で create!」する素朴な実装も計測する。
# --memory を付けると、処理時間の代わりに Processor 実行中のメモリ (RSS) の最大増加量を計測する。
# メモリの読み取りが処理時間に影響するため、時間とメモリは別々に実行して計る。
require "benchmark"

# development のSQLログ出力で遅くならないよう、計測中はログを止める
ActiveRecord::Base.logger = nil
Rails.logger.level = :warn

rows = Integer(ARGV.find { |a| a.match?(/\A\d+\z/) } || 50_000)
naive = ARGV.include?("--naive")
$measure_memory = ARGV.include?("--memory")

def measure(label)
  result = nil
  seconds = Benchmark.realtime { result = yield }
  puts format("  %-28s %7.2f 秒", label, seconds)
  result
end

def rss_mb = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0

# 処理の前後だけでなく途中も 20ms ごとに RSS を読み、処理前からの最大の増加量を返す
def peak_rss_increase_mb
  GC.start
  before = peak = rss_mb
  sampler = Thread.new { loop { peak = [ peak, rss_mb ].max; sleep 0.02 } }
  yield
  [ peak, rss_mb ].max - before
ensure
  sampler&.kill
end

def measure_processor(import)
  if $measure_memory
    puts format("  %-28s %7.0f MB", "メモリ (RSS) の最大増加", peak_rss_increase_mb { EmployeeImports::Processor.call(import) })
  else
    measure("合計") { EmployeeImports::Processor.call(import) }
  end
end

def with_fresh_tenant
  tenant = Tenant.create!(name: "計測用テナント #{Time.current.to_i}")
  50.times { |i| tenant.departments.create!(name: "部署#{i}") }
  user = tenant.users.create!(name: "計測ユーザー")
  yield tenant, user
ensure
  EmployeeImport.where(tenant:).find_each { |i| i.file.purge }
  EmployeeImport.where(tenant:).delete_all
  Employee.where(tenant:).delete_all
  Department.where(tenant:).delete_all
  User.where(tenant:).delete_all
  tenant.destroy!
end

csv = +"社員番号,氏名,email,所属部署名\n"
rows.times { |i| csv << "E#{i.to_s.rjust(6, '0')},社員 #{i},user#{i}@example.com,部署#{i % 50}\n" }
sjis = csv.encode(Encoding::CP932)
puts "行数: #{rows} / ファイルサイズ: UTF-8 #{(csv.bytesize / 1024.0 / 1024).round(2)}MB, Shift_JIS #{(sjis.bytesize / 1024.0 / 1024).round(2)}MB"

with_fresh_tenant do |tenant, user|
  puts "[段階ごとの内訳 (Shift_JIS)]"
  parsed = measure("読み込み (文字コード変換+CSV)") { EmployeeImports::CsvReader.read(StringIO.new(sjis)) }
  result = measure("検証 (部署・重複チェック)") { EmployeeImports::RowValidator.new(tenant).validate(parsed) }
  raise "想定外の検証エラー: #{result.errors.first(3)}" if result.errors.any?

  puts "[Processor 全体 (ストレージからの取得〜登録完了)]"
  import = tenant.employee_imports.create!(requested_by: user, file: { io: StringIO.new(sjis), filename: "bench.csv" })
  measure_processor(import)
  puts "  結果: #{import.reload.status} / #{import.imported_count} 件登録"

  puts "[既存社員 #{rows} 人がいる状態で、全行が重複エラーになる場合]"
  error_import = tenant.employee_imports.create!(requested_by: user, file: { io: StringIO.new(sjis), filename: "bench.csv" })
  measure_processor(error_import)
  puts "  結果: #{error_import.reload.status} / エラー #{error_import.error_count} 件"
end

if naive
  with_fresh_tenant do |tenant, _user|
    puts "[比較: 1 行ずつ部署を検索して create! する素朴な実装]"
    parsed = EmployeeImports::CsvReader.read(StringIO.new(csv))
    measure("合計") do
      ApplicationRecord.transaction do
        parsed.each do |row|
          department = tenant.departments.find_by!(name: row.department_name)
          tenant.employees.create!(department:, employee_number: row.employee_number, name: row.name, email: row.email)
        end
      end
    end
  end
end
