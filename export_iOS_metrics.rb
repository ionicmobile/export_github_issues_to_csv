require 'octokit'
require 'csv'
require 'date'
require 'rubygems'
require 'highline/import'
require './label_state_history.rb'

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

if (CSV_FILENAME.nil? || CSV_FILENAME.size < 1)
  csv_file = ask("Enter output file path: ")
else
  csv_file = CSV_FILENAME
end


client = Octokit::Client.new(:login => username, :password => password)

csv = CSV.new(File.open(File.dirname(__FILE__) + csv_file, 'w'))

puts "Initialising CSV file " + csv_file + "..."
#CSV Headers
header = [
  "Repo",
  "Title",
  "Description",
  "URL",
  "State",
  "Size",
  "Time in Dev (minutes)",
  "Time in QA (minutes)",
  "Cycle Time (CIP to RFD in minutes)"
]
# We need to add a column for each comment, so this dictates how many comments for each issue you want to support
csv << header

org_repo_names = ["ionicmobile/assets",
                  "ionicmobile/insight",
                  "ionicmobile/Radar",
                  "ionicmobile/ionicmobile.github.com",
                  "ionicmobile/townhall",
                  "ionicmobile/nucleus",
                  "ionicmobile/IonicMobileFramework",
                  "ionicmobile/IonicMobileUIFramework",
                  "ionicmobile/IonicMobileUIFramework",
                  "ionicmobile/IonicAppStore",
                  "ionicmobile/devconsole"]
puts "Looking for these repositories: #{org_repo_names}"


all_issues = []

org_repo_names.each do |repo_name|
  puts "\nGathering issues in repo " + repo_name + "..."

  issues = []
  page = 0
  begin
    page = page +1
    temp_issues = client.list_issues(repo_name, :state => "open", :page => page)
    issues = issues + temp_issues
  rescue TypeError
    puts 'Issues are disabled for this repo.'
    break
  end while not temp_issues.empty?

  puts "Found " + issues.count.to_s + " issues."
  all_issues = all_issues + issues
end

puts "\n\n\n"
puts "-----------------------------"
puts "Found a total of #{all_issues.size} issues across #{org_repo_names.size} repositories."
puts "-----------------------------"

puts "Processing #{all_issues.size} issues..."
all_issues.each do |issue|

  log_this_issue = false

  puts "Processing issue #{issue['number']} at #{issue['html_url']}..."

  # Work out the type based on our existing labels
  case
    when issue['labels'].to_s =~ /Small/i
      size = "Small"
    when issue['labels'].to_s =~ /Medium/i
      size = "Medium"
    when issue['labels'].to_s =~ /Large/i
      size = "Large"
  end

  labelnames = []
  issue['labels'].each do |label|
    label.to_s =~ /name="(.+?)"/
    labelname = $1
    labelnames.push(labelname)
  end

  #puts "--------------------------------------"
  #puts "issue is: --> #{issue} <--"
  #puts "--------------------------------------"

  # Only record state for completed stories
  state = ""
  labelnames.each do |n|
    case
      when n =~ /80 - /
        log_this_issue = true
        state = "80 - QA Approved"
      when n =~ /90 - /
        log_this_issue = true
        state = "90 - Ready for Demo"
    end
  end

  if (log_this_issue)
    puts "Issue in finished state. Logging to metrics..."

    minutes_in_dev = 0
    minutes_in_qa = 0
    if (/label_state_history/.match(issue['body']))
      #puts "about to create LSH with this body: #{issue['body']}..."
      lsh = LabelStateHistory.new(issue['body'])
      minutes_in_dev = lsh.get_time_in_state(50) / 60.0
      minutes_in_qa = lsh.get_time_in_state(70) / 60.0
      minutes_cycle_time = lsh.get_time_between_states(50, 80) / 60.0
    end

    milestone = issue['milestone'] || "None"
    if (milestone != "None")
      milestone = milestone['title']
    end

    issue['html_url'] =~ /\/github.com\/(.+)\/issues\//
    repo_name = $1

    # Needs to match the header order above, date format are based on Jira default
    row = [
      repo_name,
      issue['title'],
      issue['body'],
      issue['html_url'],
      state,
      size,
      minutes_in_dev,
      minutes_in_qa,
      minutes_cycle_time
    ]
    csv << row
  else
    puts "Issue was not in a finished state.  Not logging to metrics."
  end
  puts ""
end
