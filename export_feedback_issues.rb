require './github_issue_exporter.rb'

ghie = GitHubIssueExporter.new()
show_descriptions = false
only_show_feedback = true
ghie.export_issues(show_descriptions, only_show_feedback)