# This class handles the logic associated with checking if each conditional
# statement applies to a given deploy and, if so, applying them.
#
# The only publicly-useful method is <em>ConditionalDeploy.register</em>, which
# is used in deploy.rb to add conditional elements (see README for details).
class ConditionalDeploy

  @@conditionals = []
  @@run_without_git_diff = false

  def self.register(name, opts, &block)
    raise("Already added a conditional with that name") if @@conditionals.any?{|c| c.name == name}
    @@conditionals << Capistrano::Conditional::Unit.new(name, opts, block)
  end

  def self.in_default_mode?
    @@run_without_git_diff
  end

  def skip_task(name, opts={})
    method = opts[:clear_hooks] ? :clear : :clear_actions
    msg = opts[:message] || "Skipping #{name} as preconditions to require it were not met"

    Rake::Task[name] && Rake::Task[name].send(method)

    # Need to create stub for method in case called from
    @@deploy_context.send(:task, name) do
      msg = msg.cyan if msg.respond_to?(:cyan)
      puts msg unless opts[:silent]
    end
  end

  def self.configure(context)
    @@deploy_context = context
    yield self
  end

  def initialize(context, current, deploying)
    @context = context
    @log_method = :info # TODO: make this configurable
    @to_run  = []

    @git       = Git.open( find_git_root )
    @current   = get_object current, 'currently deployed'
    @deploying = get_object deploying, 'about to be deployed'
    return if @@run_without_git_diff

    @diff    = @git.diff(current, deploying)
    @changed = @diff.stats[:files].keys.compact.sort
  end

  def apply_conditions!
    screen_conditionals
    report_plan
    run_conditionals
  end

  protected
    def find_git_root( pwd = Dir.getwd )
      path = File.join( pwd, '.git' )
      return pwd if Dir.exist?( path )
      return nil if path == '/'

      find_git_root( File.dirname( pwd ) )
    end

    def get_object(name, desc=nil)
      @git.object(name)
    rescue Git::GitExecuteError => e
      msg = desc ? "(#{desc}) #{name}" : name

      if @@conditionals.any? {|job| job.default == 'abort' }
        abort "Unable to find git object for #{msg}. Abort execution"
      else
        warn "Unable to find git object for #{msg}. Jobs will be either run or not_run depend on default config."
        @@run_without_git_diff = true
      end
    end

    def report_plan
      @plan = []
      if @@run_without_git_diff
        set_report_header_without_git
        set_report_runlist
      else
        set_report_header
        set_report_files
        set_report_runlist
      end
      log @plan
    end

    def screen_conditionals
      @@conditionals.each do |job|
        force = job.name && ENV["RUN_#{job.name.to_s.upcase}"]
        skip  = job.name && ENV["SKIP_#{job.name.to_s.upcase}"]
        next unless force || job.applies?(@changed) || (@@run_without_git_diff && job.default == 'run')
        next if skip
        @to_run << job
      end
    end

    def run_conditionals
      @to_run.each do |job|
        job.block.call(self)
      end
    end

    def set_report_header_without_git
      @plan << ''
      @plan << 'Conditional Deployment Report:'
      @plan << ''
      @plan << "\tUNABLE TO IDENTIFY THE GIT HISTORY BETWEEN DEPLOYED AND DEPLOYING BRANCHES."
      @plan << "\tFalling back to running only conditionals marked as :default => :run"
      @plan << ''
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

    def log(lines = "\n")
      Array(lines).each do |line|
        @context.send @log_method, " [Conditional] #{line}"
      end
    end

end
