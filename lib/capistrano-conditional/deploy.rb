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

  def self.monitor_migrations(context)
    if ARGV.any?{|v| v['deploy:migrations']} # If running deploy:migrations
      # If there weren't any changes to migrations or the schema file, then abort the deploy
      ConditionalDeploy.register :unneeded_migrations, :none_match => ['db/schema.rb', 'db/migrate'] do
        context.abort "You're running migrations, but it doesn't look like you need to!"
      end
    else # If NOT running deploy:migrations
      # If there were changes to migration files, run migrations as part of the deployment
      ConditionalDeploy.register :forgotten_migrations, :any_match => ['db/schema.rb', 'db/migrate'], :msg => "Forgot to run migrations? It's cool, we'll do it for you." do
        context.after "deploy:update_code", "deploy:migrate"
      end  
    end    
  end

  def self.apply_conditions!(deployed)
    conditional = self.new(deployed)
    conditional.ensure_local_up_to_date
    conditional.screen_conditionals
    conditional.report_plan
    conditional.run_conditionals
    abort "Done"
  end



  def initialize(compare_to = 'HEAD^')
    @logger = Capistrano::Logger.new(:output => STDOUT)
    @logger.level = Capistrano::Logger::MAX_LEVEL
    
    @verbose = true
    @git = Git.open('.')
    @last_deployed = @git.object(compare_to)
    @diff = @git.diff('HEAD', compare_to)
    @changed = @diff.stats[:files].keys.sort
    @to_run = []
  end

  def ensure_local_up_to_date
    return true if ENV['ALLOW_UNCOMMITTED']
    s = @git.status
    no_changes = %w(changed added deleted).all? { |attrib| s.send(attrib).empty? }

    unless no_changes
      abort "\nYour working copy contains local changes not yet committed to git. \nPlease commit all changes before deploying.\n\n"
    end
  end

  def report_plan
    def log(text = "\n", level = Capistrano::Logger::TRACE)
      @logger.log(level, text, "Conditional")
    end
    
    log
    log "Conditional Deployment Report:", Capistrano::Logger::IMPORTANT
    log
    log "\tLast deployed commit: #{@last_deployed.message}", Capistrano::Logger::DEBUG
    log
    log "\tFiles Modified:", Capistrano::Logger::DEBUG
    @changed.each {|f| log "\t\t- #{f}"}
    log
    log "\tConditional Runlist:", Capistrano::Logger::DEBUG
    if @to_run.empty?
      log "\t\t* No conditional tasks have been added"
    else
      @to_run.each do |job|
        out = job.message ? "#{job.name} (#{job.message})" : job.name
        log "\t\t* Running #{out}"
      end
    end
    log
  end

  def screen_conditionals
    @@conditionals.each do |job|
      force = job.name && ENV["RUN_#{job.name.to_s.upcase}"]
      next unless force || job.applies?(@changed)
      @to_run << job
    end
  end
  
  def run_conditionals
    @to_run.each do |job|
      job.block.call
    end
  end
end
