# This class handles the logic associated with checking if each conditional
# statement applies to a given deploy and, if so, applying them.
#
# The only publicly-useful method is <em>ConditionalDeploy.register</em>, which
# is used in deploy.rb to add conditional elements (see README for details).
class ConditionalDeploy

  @@conditionals = []

  def self.register(name, opts, &block)
    raise("Already added a conditional with that name") if @@conditionals.any?{|c| c.name == name}
    @@conditionals << Capistrano::Conditional::Unit.new(name, opts, block)
  end

  def self.configure
    yield self
  end

  def self.monitor_migrations(context)
    if ARGV.any?{|v| v['deploy:migrations']} # If running deploy:migrations
      # If there weren't any changes to migrations or the schema file, then abort the deploy
      ConditionalDeploy.register :unneeded_migrations, :none_match => ['db/schema.rb', 'db/migrate'] do
        context.send :abort, "You're running migrations, but it doesn't look like you need to!"
      end
    else # If NOT running deploy:migrations
      # If there were changes to migration files, run migrations as part of the deployment
      ConditionalDeploy.register :forgotten_migrations, :any_match => ['db/schema.rb', 'db/migrate'], :msg => "Forgot to run migrations? It's cool, we'll do it for you." do
        context.after "deploy:update_code", "deploy:migrate"
      end
    end
  end

  def initialize(current, deploying)
    @logger = Capistrano::Logger.new(:output => STDOUT)
    @logger.level = Capistrano::Logger::MAX_LEVEL

    @verbose = true
    @git       = Git.open('.')
    @working   = get_object 'HEAD'
    @current   = get_object current, 'currently deployed'
    @deploying = get_object deploying, 'about to be deployed'

    @diff    = @git.diff(current, deploying)
    @changed = @diff.stats[:files].keys.compact.sort
    @to_run  = []
  end

  def apply_conditions!
    screen_conditionals
    report_plan
    run_conditionals
  end

  protected

    def get_object(name, desc=nil)
      @git.object(name)
    rescue Git::GitExecuteError => e
      msg = desc ? "(#{desc}) #{name}" : name
      abort "Unable to find git object for #{msg}. Is your local repository up to date?\n\n"
    end

    def report_plan
      @plan = []
      set_report_header
      set_report_files
      set_report_runlist
      log_plan @plan
    end

    def screen_conditionals
      @@conditionals.each do |job|
        force = job.name && ENV["RUN_#{job.name.to_s.upcase}"]
        skip  = job.name && ENV["SKIP_#{job.name.to_s.upcase}"]
        next unless force || job.applies?(@changed)
        next if skip
        @to_run << job
      end
    end

    def run_conditionals
      @to_run.each do |job|
        job.block.call
      end
    end

    def set_report_header
      @plan << ''
      @plan << 'Conditional Deployment Report:'
      @plan << ''
      @plan << "\tCurrently deployed:  #{commit_details @current}"
      @git.log.between(@current, @deploying).each{|l| @plan << "\t\t* #{commit_details l}"}
      @plan << "\tPreparing to deploy: #{commit_details @deploying}"
      @plan << ''
    end

    def set_report_files
      if @changed.length == 0
        @plan << "\tNo files were modified."
      else
        @plan << "\tFiles Modified:"
        @changed.each do |file|
          @plan << "\t\t- #{file}"
        end
      end
      @plan << ''
    end

    def set_report_runlist
      @plan << "\tConditional Runlist:"
      @plan << ''
      if @to_run.empty?
        @plan << "\t\t* No conditional tasks have been added"
      else
        @to_run.each do |job|
          out = job.message ? "#{job.name} (#{job.message})" : job.name
          @plan << "\t\t* Running #{out}"
        end
      end
      @plan << ''
    end

    def commit_details(c)
      # extra = "(#{c.author.name} at #{c.date.strftime("%H:%M %Z on %B %e")})"
      "#{c.sha} #{c.message.split("\n").first}"
    end

    def log_plan(lines = "\n", level = Capistrano::Logger::TRACE)
      Array(lines).each do |line|
        @logger.log(level, ': ' + line, "Conditional")
      end
    end

end
