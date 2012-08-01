Capistrano::Configuration.instance(:must_exist).load do
  log_formatter([
    { :match => /^Conditional$/, :color => :cyan, :style => :dim, :priority => 10 }
  ])
  
  
  abort "\ncapistrano-conditional is not compatible with Capistrano 1.x\n" unless respond_to?(:namespace)
  abort "\nGit is not defined (are you in a git repository, with the Git gem installed?)\n" unless defined?(Git)

  namespace :conditional do
    desc "Initializes the conditional deployment functionality"
    task :apply do
      deployed_hash = capture("cat #{current_path}/REVISION").strip
      ConditionalDeploy.apply_conditions!( deployed_hash )
    end
    
    desc "Tests to be sure that the newest local and remote git commits match"
    task :ensure_latest_git do
      remote = capture("cd #{shared_path}/cached-copy && git log --format=oneline -n 1", :pty => false)
      local = run_locally("git log --format=oneline -n 1")
      
      unless local == remote
        abort("\nLocal and remote git repositories have different HEADs:\n    Local: #{local}    Remote: #{remote}\n    Make sure you've committed your latest changes, or else pull down the remote updates and try again\n")
      end
    end
  end

  # Ensure deploys apply conditional elements before running the rest of the tasks
  before 'deploy', 'conditional:apply'
  before 'deploy:migrations', 'conditional:apply'
  
  # Abort deployment if mismatch between local and remote git repositories
  after 'deploy:update_code', 'conditional:ensure_latest_git'
end
