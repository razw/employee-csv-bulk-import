namespace :graphql do
  desc "GraphQL のスキーマを schema.graphql に書き出す (型や項目を変えたら実行してコミットする)"
  task dump_schema: :environment do
    path = Rails.root.join("schema.graphql")
    path.write(EmployeeCsvBulkImportSchema.to_definition)
    puts "#{path.relative_path_from(Rails.root)} を更新しました"
  end
end
