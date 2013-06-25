require 'octokit'
require 'csv'
require 'date'
require 'rubygems'
require 'highline/import'

class GitHubIssueExporter
  @@show_descriptions = false
  @@only_show_feedback = false

  #### Public Methods ####

  def initialize(show_descriptions = false, only_show_feedback = false, pretty_output = false)
    @@show_descriptions = show_descriptions
    @@only_show_feedback = only_show_feedback
    @@pretty_output = pretty_output
  end

  def export_issues
    org = get_github_organization()
    octokit_client = github_connection(org)
    all_issues = get_all_issues(octokit_client, org)
    loop_all_issues_and_write_to_csv(get_csv_filename(), all_issues)
  end

  def export_milestone_status
    org = get_github_organization()
    octokit_client = github_connection(org)

    csv = CSV.new(File.open(File.dirname(__FILE__) + get_csv_filename(), 'w'))
    header = ["Repo",
              "Milestone",
              "Release Notes",
              "Due Date",
              "% Complete",
              "Open Stories",
              "Finished But Not Closed Stories",
              "Closed Stories",
              "URL"
    ]
    csv << header

    repo_names = get_all_repo_names(octokit_client, org)
    repo_names.each do |repo_name|
      milestones = octokit_client.list_milestones(repo_name)
      milestones.each do |milestone|
        next if milestone.is_a?(Array) # error message is an array
        puts "milestone number: #{milestone['number']}"
        milestone_number = milestone['number']
        open_milestone_issues = octokit_client.list_issues(repo_name, {:milestone => milestone_number, :state => 'open'} )
        num_finished_but_not_closed = 0
        open_milestone_issues.each do |open_issue|
          if (get_queue_state(open_issue) == "QA Approved")
            num_finished_but_not_closed += 1
          end
        end

        num_open = milestone['open_issues']
        num_closed = milestone['closed_issues']
        total = num_open + num_closed
        percent_complete = (num_closed.to_f + num_finished_but_not_closed.to_f) / (total.to_f)
        percent_complete = 0 if (num_open == 0 && num_closed == 0)
        puts "milestone is: #{milestone}"
        row = [repo_name,
               milestone['title'],
               milestone['description'],
               milestone['due_on'],
               percent_complete,
               num_open,
               num_finished_but_not_closed,
               num_closed,
               milestone['url']
        ]
        csv << row
      end
    end
  end


  #### Private Methods ####
  private
  def pretty_puts(stuff)
    puts stuff unless @@pretty_output == false
  end

  private
  def get_all_milestones(octokit_client, github_organization)
    org_repo_names = get_all_repo_names(octokit_client, github_organization)
    all_milestones = []
    org_repo_names.each do |repo_name|
      milestones = octokit_client.list_milestones(repo_name)
      all_milestones += milestones
    end
    return all_milestones
  end

  private
  def github_connection(github_org)
    gh_username = ENV['GITHUB_USERNAME']
    gh_password = ENV['GITHUB_PASSWORD']

    pretty_puts "Getting ready to pull down all issues in the " + github_org + " organization."

    if (gh_username.nil? || gh_username.size < 1)
      username = ask("Enter Github username: ")
    else
      pretty_puts "Github username: #{gh_username}"
      username = gh_username
    end

    if (gh_password.nil? || gh_password.size < 1)
      password = ask("Enter Github password: ") { |q| q.echo = false }
    else
      password = gh_password
      pretty_puts "Github password: ***********"
    end

    client = Octokit::Client.new(:login => username, :password => password)
    return client
  end

  private
  def get_all_repo_names(octokit_client, github_organization)
    pretty_puts "Finding this organization's repositories..."
    org_repos = octokit_client.organization_repositories(github_organization, :per_page => 100)
    pretty_puts "\nFound " + org_repos.count.to_s + " repositories:"
    org_repo_names = []
    org_repos.each do |r|
      org_repo_names.push r['full_name']
      pretty_puts r['full_name']
    end
    return org_repo_names
  end

  private
  def get_all_issues(octokit_client, github_organization)
    all_issues = []
    org_repo_names = get_all_repo_names(octokit_client, github_organization)
    org_repo_names.each do |repo_name|
      pretty_puts "\nGathering issues in repo " + repo_name + "..."
      temp_issues = []
      issues = []
      page = 0
      begin
        page = page +1
        temp_issues = octokit_client.list_issues(repo_name, :state => 'closed', :page => page)
        issues = issues + temp_issues
      rescue TypeError
        break
      end while not temp_issues.empty?
      temp_issues = []
      page = 0
      begin
        page = page +1
        temp_issues = octokit_client.list_issues(repo_name, :state => 'open', :page => page)
        issues = issues + temp_issues
      rescue TypeError
        pretty_puts 'Issues are disabled for this repo.'
        break
      end while not temp_issues.empty?

      pretty_puts "Found " + issues.count.to_s + " issues."

      all_issues = all_issues + issues
    end
    return all_issues
  end

  private
  def loop_all_issues_and_write_to_csv(filename, all_issues)
    csv = CSV.new(File.open(File.dirname(__FILE__) + filename, 'w'))

    pretty_puts "Initialising CSV file " + filename + "..."
    header = ["Repo", "Title"]
    header.push "Description" if @@show_descriptions
    header.push "Date Created"
    header.push "Date Modified"
    header.push "Date Closed"
    header.push "Issue Type"
    header.push "Milestone"
    header.push "State"
    header.push "Feedback"
    header.push "Priority"
    header.push "External"
    header.push "Lemon"
    header.push "MissedAC"
    header.push "Open/Closed"
    header.push "Reporter"
    header.push "URL"

    csv << header

    pretty_puts "\n\n\n"
    pretty_puts "-----------------------------"
    pretty_puts "Found a total of #{all_issues.size} issues across all repositories."
    pretty_puts "-----------------------------"

    pretty_puts "Processing #{all_issues.size} issues..."
    all_issues.each do |issue|
      pretty_puts "Processing issue #{issue['number']} at #{issue['html_url']}..."
      issue['html_url'] =~ /\/github.com\/(.+)\/issues\//
      repo_name = $1
      feedback = is_feedback(issue)

      row = [repo_name, issue['title']]
      row.push issue['body'] if @@show_descriptions
      row.push get_created_at_time(issue)
      row.push get_updated_at_time(issue)
      row.push get_closed_at_time(issue)
      row.push get_type(issue)
      row.push get_milestone(issue)
      row.push get_queue_state(issue)
      row.push feedback
      row.push get_priority(issue)
      row.push is_external(issue)
      row.push is_lemon(issue)
      row.push is_missed_AC(issue)
      row.push issue['state']
      row.push issue['user']['login']
      row.push issue['html_url']

      csv << row unless (@@only_show_feedback && feedback == 0)
    end
  end

  private
  def get_csv_filename
    env_csv_filename = ENV['GITHUB_DEFAULT_CSV_FILENAME']
    if (env_csv_filename.nil? || env_csv_filename.size < 1)
      csv_file = ask("Enter output file path: ")
    else
      csv_file = env_csv_filename
    end
    return csv_file
  end

  private
  def get_github_organization
    gh_org = ENV['GITHUB_ORGANIZATION_NAME']
    gh_org = ask("Enter Github organization name: ") if gh_org.nil?
    return gh_org
  end

  private
  def get_timezone_offset
    timezone_offset = ENV['GITHUB_TIMEZONE_OFFSET']
    timezone_offset = "-5" if (timezone_offset.nil?)
    return timezone_offset
  end

  private
  def get_label_names(issue)
    labelnames = []
    issue['labels'].each do |label|
      label.to_s =~ /name="(.+?)"/
      labelname = $1
      labelnames.push(labelname)
    end
    return labelnames
  end

  private
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

  private
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

  private
  def get_milestone(issue)
    milestone = issue['milestone'] || "None"
    if (milestone != "None")
      milestone = milestone['title']
    end
    return milestone
  end

  private
  def get_closed_at_time(issue)
    closed_at_time = issue['closed_at'] ? DateTime.parse(issue['closed_at']).new_offset(get_timezone_offset()).strftime("%d/%b/%y %l:%M %p") : ""
    return closed_at_time
  end

  private
  def get_created_at_time(issue)
    return DateTime.parse(issue['created_at']).new_offset(get_timezone_offset()).strftime("%d/%b/%y %l:%M %p")
  end

  private
  def get_updated_at_time(issue)
    return DateTime.parse(issue['updated_at']).new_offset(get_timezone_offset()).strftime("%d/%b/%y %l:%M %p")
  end

  private
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

  private
  def is_feedback(issue)
    label_string = issue['labels'].to_s

    feedback = 0
    feedback = 1 if label_string =~ /Feedback/i
    return feedback
  end

  private
  def is_external(issue)
    label_string = issue['labels'].to_s

    external = 0
    external = 1 if label_string =~ /External/i
    return external
  end

  private
  def is_lemon(issue)
    label_string = issue['labels'].to_s

    lemon = 0
    lemon = 1 if label_string =~ /Lemon/i
    return lemon
  end

  private
  def is_missed_AC(issue)
    label_string = issue['labels'].to_s

    missedAC = 0
    missedAC = 1 if label_string =~ /MissedAC/i
    return missedAC
  end

end

