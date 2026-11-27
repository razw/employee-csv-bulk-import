# employee-csv-bulk-import

従業員情報の CSV をアップロードし、従業員を一括で新規登録する機能のサンプル実装 (Rails API / GraphQL / Sidekiq)。

設計の詳細は [docs/design.md](docs/design.md) を参照。

## 特徴

- 1 分のリクエストタイムアウトに影響されないよう、S3 への直接アップロードと非同期ジョブで処理する
- 5 万行を約 3.5 秒で登録 (1 行ずつ登録する実装は約 80 秒)
- 1 件でもエラーがあれば 1 件も登録しない (All-or-Nothing)。エラーは行番号・列名・理由で返す
- Excel で保存した Shift_JIS の CSV や、全角英数字などの表記ゆれに対応する

## 動かし方

必要なもの: Ruby (`.ruby-version`)、PostgreSQL、Redis

```bash
bundle install
bin/rails db:setup        # テーブル作成とサンプルデータ (テナント・ユーザー・部署) の投入
bin/ci                    # RuboCop・Brakeman・bundler-audit・RSpec をまとめて実行 (GitHub Actions と同じ確認)
```

5 万行の計測:

```bash
bin/rails runner script/benchmark_import.rb 50000 --naive
```

メモリの計測 (時間とは別に実行する):

```bash
bin/rails runner script/benchmark_import.rb 50000 --memory
```

API サーバーとワーカーの起動:

```bash
bin/rails server
bundle exec sidekiq -C config/sidekiq.yml
```

## 開発の進め方

設計とプロトタイプで仕様を固めたあと、生成 AI (Claude Code) を使い、次の順で作り直した。コミット履歴と GitHub Actions の実行履歴で、この順番をそのまま追える。

1. Rails の雛形と設計書を置く
2. 実装に入る前に、AI エージェントのガードレールと CI を整える
   - [AGENTS.md](AGENTS.md): 完了の条件、テスト駆動の進め方、壊してはいけない性質、禁止事項。`CLAUDE.md` から読み込む
   - [.claude/settings.json](.claude/settings.json): 秘密情報の読み取りと force push を禁止する。Ruby ファイルを編集するたびに `rubocop -a` をかけ、直しきれない違反をエージェントに返すフックを入れる
   - [.github/workflows/ci.yml](.github/workflows/ci.yml): RuboCop・Brakeman・bundler-audit・RSpec を実行する
3. 機能ごとに、テストを先にコミットして CI が赤になることを確かめ、次に実装をコミットして緑にする
4. プロトタイプのレビューで見つかった不具合 (同じインポートの並行実行、他テナントのファイル、正規化すると同じ名前になる部署) も、まず失敗するテストで再現してから直す

コードと設計書の多くは Claude Code が書いた。人は仕様の解釈と設計の方針を決め、AI の提案や、別の AI によるレビューの指摘を採るかどうかを判断した。

## 主なファイル

| パス | 内容 |
|---|---|
| `app/graphql/mutations/create_direct_upload.rb` | 直接アップロード用の署名付き URL を発行 |
| `app/graphql/mutations/create_employee_import.rb` | インポートを受け付け、ジョブを投入 |
| `app/graphql/types/query_type.rb` | インポートの進捗と結果を返す |
| `app/jobs/employee_import_job.rb` | リトライ設定付きのジョブ |
| `app/services/employee_imports/csv_reader.rb` | 文字コード判定・ヘッダー確認・行データへの変換 |
| `app/services/employee_imports/row_validator.rb` | 正規化と検証 (まとめて照合) |
| `app/services/employee_imports/processor.rb` | 全件登録またはエラー保存 |
| `db/migrate/` | テーブル定義 (一意制約・同時実行制御のインデックス) |
