class ConditionalDeploy

  @@conditionals = []

  def self.register(name, opts, &block)
    @@conditionals << Capistrano::Conditional::Unit.new(name, opts, block)
  end


  def self.apply_conditions!(deployed)
    conditional = self.new(deployed)
    conditional.ensure_local_up_to_date
    conditional.run_conditionals
    conditional.report_plan

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
    s = @git.status
    no_changes = %w(changed added deleted).all? { |attrib| s.send(attrib).empty? }

    unless no_changes
      abort "\nYour working copy contains local changes not yet committed to git. \nPlease commit all changes before deploying.\n\n"
    end
  end

  def report_plan
    def log(text)
      @logger.log(Capistrano::Logger::IMPORTANT, text, "Conditional")
    end
    
    log
    log "\tLast deployed commit: #{@last_deployed.message}"
    log
    log "\tFiles Modified:"
    @changed.each {|f| log "\t\t- #{f}"}
    log
    log "\tConditional Runlist:"
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

  def run_conditionals
    @@conditionals.each do |job|
      force = job.name && ENV["RUN_#{job.name.to_s.upcase}"]
      next unless force || job.applies?(@changed)
      @to_run << job
    end
  end  
end
