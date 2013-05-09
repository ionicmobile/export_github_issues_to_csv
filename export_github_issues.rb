require './github_issue_exporter.rb'

ghie = GitHubIssueExporter.new()
show_descriptions = false
ghie.export_issues(show_descriptions)