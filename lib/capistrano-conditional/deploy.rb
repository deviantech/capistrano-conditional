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
    puts "\n" * 3
    puts "Conditional Deployment:"
    puts "\tLast deployed commit: #{@last_deployed.message}"
    puts
    puts "\tFiles Modified:"
    @changed.each {|f| puts "\t\t- #{f}"}
    puts
    puts "\tConditional Runlist:"
    if @to_run.empty?
      puts "\t\t* No conditional tasks have been added"
    else
      @to_run.each do |job|
        out = job.message ? "#{job.name} (#{job.message})" : job.name
        puts "\t\t* Running #{out}"
      end
    end
    puts "\n" * 3
  end

  def run_conditionals
    @@conditionals.each do |job|
      force = job.name && ENV["RUN_#{job.name.to_s.upcase}"]
      next unless force || job.applies?(@changed)
      @to_run << job
    end
  end  
end
