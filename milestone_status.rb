require 'octokit'
require 'csv'
require 'date'
require 'rubygems'
require 'highline/import'

TIMEZONE_OFFSET=ENV['GITHUB_TIMEZONE_OFFSET']
CSV_FILENAME=ENV['GITHUB_DEFAULT_CSV_FILENAME']
GITHUB_ORGANIZATION=ENV['GITHUB_ORGANIZATION_NAME']
GITHUB_USERNAME=ENV['GITHUB_USERNAME']
GITHUB_PASSWORD=ENV['GITHUB_PASSWORD']

TIMEZONE_OFFSET = "-5" if (TIMEZONE_OFFSET.nil?)

GITHUB_ORGANIZATION = ask("Enter Github organization name: ") if GITHUB_ORGANIZATION.nil?
puts "Getting ready to pull down all issues in the " + GITHUB_ORGANIZATION + " organization."

if (GITHUB_USERNAME.nil? || GITHUB_USERNAME.size < 1)
  username = ask("Enter Github username: ")
else
  puts "Github username: #{GITHUB_USERNAME}"
  username = GITHUB_USERNAME
end

if (GITHUB_PASSWORD.nil? || GITHUB_PASSWORD.size < 1)
  password = ask("Enter Github password: ") { |q| q.echo = false }
else
  password = GITHUB_PASSWORD
  puts "Github password: ***********"
end


client = Octokit::Client.new(:login => username, :password => password)

csv = CSV.new(File.open(File.dirname(__FILE__) + "milestone_status.csv", 'w'))

puts "Initialising CSV file milestone_status.csv..."
header = [
  "Repo",
  "Milestone",
  "% Complete",
  "Release Date",
  "Issues Completed",
  "Total Issues",
  "Milestone URL"
]
csv << header

puts "Finding this organization's repositories..."
org_repos = client.organization_repositories(GITHUB_ORGANIZATION, :per_page => 100)
puts "\nFound " + org_repos.count.to_s + " repositories:"
org_repo_names = []
org_repos.each do |r|
  org_repo_names.push r['full_name']
  puts r['full_name']
end

all_milestones = []

org_repo_names.each do |repo_name|
  puts "\nFinding milestones in repo " + repo_name + "..."
  temp = client.list_milestones(repo_name)
  puts "temp -> #{temp}"

  all_milestones += temp if temp.kind_of?(Array)
  puts "Found " + all_milestones.count.to_s + " milestones."
end

puts "\n\n\n"
puts "-----------------------------"
puts "Found a total of #{all_milestones.size} milestones across #{org_repos.size} repositories."
puts "-----------------------------"

puts "Processing milestones..."
all_milestones.each do |mile|

  puts "Full milestone:"
  puts "#{mile}"

  ## Work out the type based on our existing labels
  #label_string = issue['labels'].to_s
  #type = "Bug"         if label_string =~ /Bug/i
  #type = "Enhancement" if label_string =~ /Enhancement/i
  #feedback = 1         if label_string =~ /Feedback/i
  #external = 1         if label_string =~ /External/i
  #
  #labelnames = []
  #issue['labels'].each do |label|
  #  label.to_s =~ /name="(.+?)"/
  #  labelname = $1
  #  labelnames.push(labelname)
  #end
  #
  #milestone = issue['milestone'] || "None"
  #if (milestone != "None")
  #  milestone = milestone['title']
  #end
  #
  #issue['html_url'] =~ /\/github.com\/(.+)\/issues\//
  #repo_name = $1
  #
  #closed_at_time = issue['closed_at'] ? DateTime.parse(issue['closed_at']).new_offset(TIMEZONE_OFFSET).strftime("%d/%b/%y %l:%M %p") : ""
  #
  ## Needs to match the header order above, date format are based on Jira default
  #row = [
  #  repo_name,
  #  issue['title'],
  #  issue['body'],
  #  DateTime.parse(issue['created_at']).new_offset(TIMEZONE_OFFSET).strftime("%d/%b/%y %l:%M %p"),
  #  DateTime.parse(issue['updated_at']).new_offset(TIMEZONE_OFFSET).strftime("%d/%b/%y %l:%M %p"),
  #  closed_at_time,
  #  type,
  #  milestone,
  #  state,
  #  feedback,
  #  priority,
  #  external,
  #  issue['state'],
  #  issue['user']['login'],
  #  issue['html_url']
  #]
  #csv << row
  end
