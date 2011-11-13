Capistrano::Configuration.instance(:must_exist).load do
  abort "capistrano-conditional is not compatible with Capistrano 1.x." unless respond_to?(:namespace)
  
  require 'git'
  abort "Git is not defined (are you in a git repository, with the Git gem installed?)" unless defined?(Git)

  namespace :conditional do
    desc "Initializes the conditional deployment functionality"
    task :apply do
      log = capture("cd #{current_path} && git log --format=oneline -n 1", :pty => false)
      ConditionalDeploy.apply_conditions!( log.split[0] )
    end
  end

  before 'deploy', 'conditional:apply'
  before 'deploy:migrations', 'conditional:apply'
end
