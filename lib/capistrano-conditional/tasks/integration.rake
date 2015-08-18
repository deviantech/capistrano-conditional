abort "\nGit is not defined (are you in a git repository, with the Git gem installed?)\n" unless defined?(Git)

# By default, assume using multi-stage deployment setting :branch variable, and that the local branch is up to date
# (although don't require being on that branch to deploy).
set :git_deploying, -> { fetch(:branch).nil? ? 'HEAD' : "origin/#{fetch(:branch)}"}

namespace :conditional do
  desc "Initializes the conditional deployment functionality"
  task :apply do
    on primary(:app) do
      currently_deployed = capture("cat #{current_path}/REVISION").strip rescue nil
      @deploy = ConditionalDeploy.new(self, currently_deployed, fetch(:git_deploying))
      @deploy.apply_conditions!
    end
  end
end

# Ensure deploys apply conditional elements before running the rest of the tasks
before 'deploy:starting', 'conditional:apply'
