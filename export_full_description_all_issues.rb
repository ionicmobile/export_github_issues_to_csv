require './github_issue_exporter.rb'

ghie = GitHubIssueExporter.new(true)
ghie.export_issues()