require './github_issue_exporter.rb'

ghie = GitHubIssueExporter.new()
ghie.export_issues()