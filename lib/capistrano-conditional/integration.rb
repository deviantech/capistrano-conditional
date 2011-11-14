Capistrano::Configuration.instance(:must_exist).load do
  abort "\ncapistrano-conditional is not compatible with Capistrano 1.x\n" unless respond_to?(:namespace)
  abort "\nGit is not defined (are you in a git repository, with the Git gem installed?)\n" unless defined?(Git)

  namespace :conditional do
    desc "Initializes the conditional deployment functionality"
    task :apply do
      log = capture("cd #{current_path} && git log --format=oneline -n 1", :pty => false)
      ConditionalDeploy.apply_conditions!( log.split[0] )
    end
  end

  # Ensure deploys apply conditional elements before running the rest of the tasks
  before 'deploy', 'conditional:apply'
  before 'deploy:migrations', 'conditional:apply'
end
