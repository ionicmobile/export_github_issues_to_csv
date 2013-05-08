require 'octokit'
require 'csv'
require 'date'
require 'rubygems'
require 'highline/import'

class GitHubIssueExporter
  def export_issues
    org = get_github_organization()
    octokit_client = github_connection(org)
    all_issues = get_all_issues(octokit_client, org)
    loop_all_issues_and_write_to_csv(csv_filename(), all_issues)
  end

  def csv_filename
    env_csv_filename = ENV['GITHUB_DEFAULT_CSV_FILENAME']
    if (env_csv_filename.nil? || env_csv_filename.size < 1)
      csv_file = ask("Enter output file path: ")
    else
      csv_file = env_csv_filename
    end
    return csv_file
  end

  def get_github_organization
    gh_org = ENV['GITHUB_ORGANIZATION_NAME']
    gh_org = ask("Enter Github organization name: ") if gh_org.nil?
    return gh_org
  end

  def get_timezone_offset
    timezone_offset = ENV['GITHUB_TIMEZONE_OFFSET']
    timezone_offset = "-5" if (timezone_offset.nil?)
    return timezone_offset
  end

  def github_connection(github_org)
    gh_username = ENV['GITHUB_USERNAME']
    gh_password = ENV['GITHUB_PASSWORD']

    puts "Getting ready to pull down all issues in the " + github_org + " organization."

    if (gh_username.nil? || gh_username.size < 1)
      username = ask("Enter Github username: ")
    else
      puts "Github username: #{gh_username}"
      username = gh_username
    end

    if (gh_password.nil? || gh_password.size < 1)
      password = ask("Enter Github password: ") { |q| q.echo = false }
    else
      password = gh_password
      puts "Github password: ***********"
    end

    client = Octokit::Client.new(:login => username, :password => password)
    return client
  end

  def get_all_issues(octokit_client, github_organization)
    puts "Finding this organization's repositories..."
    org_repos = octokit_client.organization_repositories(github_organization, :per_page => 100)
    puts "\nFound " + org_repos.count.to_s + " repositories:"
    org_repo_names = []
    org_repos.each do |r|
      org_repo_names.push r['full_name']
      puts r['full_name']
    end

    all_issues = []

    org_repo_names.each do |repo_name|
      puts "\nGathering issues in repo " + repo_name + "..."
      temp_issues = []
      issues = []
      page = 0
      begin
        page = page +1
        temp_issues = octokit_client.list_issues(repo_name, :state => "closed", :page => page)
        issues = issues + temp_issues
      rescue TypeError
        break
      end while not temp_issues.empty?
      temp_issues = []
      page = 0
      begin
        page = page +1
        temp_issues = octokit_client.list_issues(repo_name, :state => "open", :page => page)
        issues = issues + temp_issues
      rescue TypeError
        puts 'Issues are disabled for this repo.'
        break
      end while not temp_issues.empty?

      puts "Found " + issues.count.to_s + " issues."

      all_issues = all_issues + issues
    end
    return all_issues
  end

  def loop_all_issues_and_write_to_csv(filename, all_issues)
    csv = CSV.new(File.open(File.dirname(__FILE__) + filename, 'w'))

    puts "Initialising CSV file " + filename + "..."
    header = [
        "Repo",
        "Title",
        "Description",
        "Date Created",
        "Date Modified",
        "Date Closed",
        "Issue Type",
        "Milestone",
        "State",
        "Feedback",
        "Priority",
        "External",
        "Lemon",
        "MissedAC",
        "Open/Closed",
        "Reporter",
        "URL"
    ]
    csv << header

    puts "\n\n\n"
    puts "-----------------------------"
    puts "Found a total of #{all_issues.size} issues across all repositories."
    puts "-----------------------------"

    puts "Processing #{all_issues.size} issues..."
    all_issues.each do |issue|
      puts "Processing issue #{issue['number']} at #{issue['html_url']}..."
      issue['html_url'] =~ /\/github.com\/(.+)\/issues\//
      repo_name = $1

      # Needs to match the header order above, date format are based on Jira default
      row = [
          repo_name,
          issue['title'],
          issue['body'],
          get_created_at_time(issue),
          get_updated_at_time(issue),
          get_closed_at_time(issue),
          get_type(issue),
          get_milestone(issue),
          get_queue_state(issue),
          is_feedback(issue),
          get_priority(issue),
          is_external(issue),
          is_lemon(issue),
          is_missed_AC(issue),
          issue['state'],
          issue['user']['login'],
          issue['html_url']
      ]
      csv << row
    end
  end

  def get_label_names(issue)
    labelnames = []
    issue['labels'].each do |label|
      label.to_s =~ /name="(.+?)"/
      labelname = $1
      labelnames.push(labelname)
    end
    return labelnames
  end

  def get_queue_state(issue)
    labelnames = get_label_names(issue)
    state = ""
    labelnames.each do |n|
      case
        when n =~ /10 - Backlog/i
          state = "Backlog"
        when n =~ /Design Backlog/i
          state = "Design Backlog"
        when n =~ /Design in Process/i
          state = "Design in Process"
        when n =~ /Code Review/i
          state = "Code Review"
        when n =~ /Ready for Dev QA/i
          state = "Ready for Dev QA"
        when n =~ /Ready for Coding/i
          state = "Ready for Coding"
        when n =~ /Coding in Process/i
          state = "Coding in Process"
        when n =~ /Ready for QA/i
          state = "Ready for QA"
        when n =~ /QA in Process/i
          state = "QA in Process"
        when n =~ /QA Approved/i
          state = "QA Approved"
        when n =~ /Ready for Demo/i
          state = "Ready for Demo"
      end
    end
    return state
  end

  def get_priority(issue)
    labelnames = get_label_names(issue)
    priority = ""
    labelnames.each do |n|
      case
        when n =~ /Priority:1/i
          priority = 1
        when n =~ /Priority:2/i
          priority = 2
        when n =~ /Priority:3/i
          priority = 3
        when n =~ /Priority:4/i
          priority = 4
        when n =~ /Priority:5/i
          priority = 5
      end
    end
    return priority
  end

  def get_milestone(issue)
    milestone = issue['milestone'] || "None"
    if (milestone != "None")
      milestone = milestone['title']
    end
    return milestone
  end

  def get_closed_at_time(issue)
    closed_at_time = issue['closed_at'] ? DateTime.parse(issue['closed_at']).new_offset(get_timezone_offset()).strftime("%d/%b/%y %l:%M %p") : ""
    return closed_at_time
  end

  def get_created_at_time(issue)
    return DateTime.parse(issue['created_at']).new_offset(get_timezone_offset()).strftime("%d/%b/%y %l:%M %p")
  end

  def get_updated_at_time(issue)
    return DateTime.parse(issue['updated_at']).new_offset(get_timezone_offset()).strftime("%d/%b/%y %l:%M %p")
  end

  def get_type(issue)
    label_string = issue['labels'].to_s

    type = ""
    if (label_string =~ /Bug/i)
      type = "Bug"
    elsif (label_string =~ /Enhancement/i)
      type = "Enhancement"
    end
    return type
  end

  def is_feedback(issue)
    label_string = issue['labels'].to_s

    feedback = 0
    feedback = 1 if label_string =~ /Feedback/i
    return feedback
  end

  def is_external(issue)
    label_string = issue['labels'].to_s

    external = 0
    external = 1 if label_string =~ /External/i
    return external
  end

  def is_lemon(issue)
    label_string = issue['labels'].to_s

    lemon = 0
    lemon = 1 if label_string =~ /Lemon/i
    return lemon
  end

  def is_missed_AC(issue)
    label_string = issue['labels'].to_s

    missedAC = 0
    missedAC = 1 if label_string =~ /MissedAC/i
    return missedAC
  end

end

ghie = GitHubIssueExporter.new()
ghie.export_issues()