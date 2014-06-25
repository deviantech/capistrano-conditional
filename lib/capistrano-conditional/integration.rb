Capistrano::Configuration.instance(:must_exist).load do
  log_formatter([
    { :match => /^Conditional$/, :color => :cyan, :style => :dim, :priority => 10 }
  ])

  abort "\ncapistrano-conditional is not compatible with Capistrano 1.x\n" unless respond_to?(:namespace)
  abort "\nGit is not defined (are you in a git repository, with the Git gem installed?)\n" unless defined?(Git)

  # By default, assume using multi-stage deployment setting :branch variable, and that the local branch is up to date
  # (although don't require being on that branch to deploy).
  set :git_deploying, -> { fetch(:branch).blank? ? 'HEAD' : "origin/#{fetch(:branch)}"}
  set :git_currently_deployed, -> { capture("cat #{current_path}/REVISION").strip }
  set :monitor_migrations, -> { false }

  namespace :conditional do
    desc "Initializes the conditional deployment functionality"
    task :apply do
      ConditionalDeploy.monitor_migrations(self) if monitor_migrations

      @deploy = ConditionalDeploy.new(git_currently_deployed, git_deploying)
      @deploy.apply_conditions!
    end
  end

  # Ensure deploys apply conditional elements before running the rest of the tasks
  before 'deploy', 'conditional:apply'
  before 'deploy:migrations', 'conditional:apply'
end
