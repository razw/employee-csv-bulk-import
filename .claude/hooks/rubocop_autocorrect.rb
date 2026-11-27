# Claude Code の PostToolUse フック。
# エージェントが Ruby ファイルを編集したら rubocop -a で安全な自動修正をかける。
# 自動修正しきれない違反が残れば終了コード 2 で返し、その内容をエージェントに伝えて直させる。
require "json"

path = JSON.parse($stdin.read).dig("tool_input", "file_path").to_s
project = ENV.fetch("CLAUDE_PROJECT_DIR", Dir.pwd)
exit 0 unless path.end_with?(".rb") && File.file?(path) && File.expand_path(path).start_with?("#{project}/")

output = IO.popen(
  [ File.join(project, "bin/rubocop"), "-a", "--force-exclusion", "--format", "simple", path ],
  chdir: project, err: [ :child, :out ], &:read
)
exit 0 if $?.success?

warn "RuboCop の自動修正で直しきれない違反があります。直してください。\n#{output}"
exit 2
