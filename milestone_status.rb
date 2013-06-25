require './github_issue_exporter.rb'

show_descriptions = false
only_show_feedback = false
ghie = GitHubIssueExporter.new(show_descriptions, only_show_feedback)
ghie.export_milestone_status()

