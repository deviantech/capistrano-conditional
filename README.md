# capistrano-conditional

This gem extends capistrano v2 deployments to allow certain tasks to only be run under certain conditions -- i.e. conditionally.

It hasn't yet been extended to work with Capistrano 3; pull requests welcomed!

## BREAKING UPDATES

* v. 0.1.0 pulls the branch to be deployed from capistrano multistage, rather than assuming it's whatever you currently have checked out in your working directory (among other things, this allows tweaking the deploy recipe multiple times without having to commit those changes).

## Installation

Add to your Gemfile:

    group :development do
      gem 'capistrano-conditional', :require => false # <-- This is important!
    end

And then modify your deploy.rb to include this at the top:

    require "capistrano-conditional"

## Requirements

Your application must already be using capistrano for deployments, and (for now at least) you need to be using git.

## Usage Instructions

<code>capistrano-conditional</code> adds logic to be run before <code>cap deploy</code> or <code>cap deploy:migrations</code> that compares the to-be-deployed code with the existing remote (currently deployed) code and lists all files that will be updated by the current deploy.  It then checks the list of conditional statements that you've provided and runs any that you want run -- e.g. if you're using [whenever](https://github.com/javan/whenever) and you only want to run the <code>deploy:update_crontab</code> task if <code>config/schedule.rb</code> has been changed, you'd add a block like this to your deploy.rb:

    ConditionalDeploy.register :whenever, :watchlist => 'config/schedule.rb' do
      after "deploy:symlink", "deploy:update_crontab"
    end

This example registers a conditional named "whenever" (names aren't programmatically important, but they're used to report what's going to be run at the beginning of each deploy).  The contents of the block will be run only if the list of changed files includes a path that matches <code>config/schedule.rb</code>.

### Setting branches

By default, capistrano-conditional pics up the branch-to-be-deployed from the `:branch` setting used by capistrano multistage, or defaults to `HEAD`. To specify a different branch manually: `set :git_deploying, 'some/other/branch/name'`.

### Available Conditions

There are currently four logic conditions available (well, five, but <code>:watchlist</code> is just an alias for <code>:any_match</code>):

  * <code>:any_match</code> => file_list
  * <code>:none_match</code> => file_list
  * <code>:if</code> => Proc
  * <code>:unless</code> => Proc

Where file_list is either a string or an array of strings which will be <em>matched</em> against the list of changed filenames from git (so <code>:any_match => ['db/migrate']</code> would be true if ANY migration file was added, modified, or deleted).

<code>:any_match</code> (aliased as <code>:watchlist</code>) executes the block if ANY of the provided strings match ANY of file paths git reports changed.

<code>:none_match</code> executes the block if NONE of the provided strings match ANY of file paths git reports changed.

If you need more custom control, <code>:if</code> and <code>:unless</code> expect a Proc (which will be passed the list of changed files, if one argument is expected, or the list of changes and the git object itself, if two arguments are expected and you really want to dive into things yourself).

## Example Usage

These snippets go in <code>config/deploy.rb</code> or any other file that gets loaded via capistrano.

### A random collection of examples:

#### Using [whenever](https://github.com/javan/whenever)

Only run the rake task to update the crontab if the schedule has changed:

    ConditionalDeploy.register :whenever, :watchlist => 'config/schedule.rb' do
      after "deploy:symlink", "deploy:update_crontab"
    end

#### Using [thinking-sphinx](https://github.com/pat/thinking-sphinx)

Only restart the sphinx daemon if our database or schema has changed. Otherwise, just copy the generated sphinx config from the previous release:

    SPHINX_WATCHLIST = ['db/schema.rb', 'db/migrate', 'sphinx.yml', 'app/indices']

    ConditionalDeploy.register :sphinx, :watchlist => SPHINX_WATCHLIST do
      before "deploy:update_code",  "thinking_sphinx:stop"
      before "deploy:start",        "thinking_sphinx:start"
      before "deploy:restart",      "thinking_sphinx:start"
    end

    ConditionalDeploy.register :no_sphinx, :none_match => SPHINX_WATCHLIST do
      after "deploy:update_code", "sphinx:copy_config"
    end

    namespace :sphinx do
      desc 'Copy the config file from previous release, if available, or else rerun configuration'
      task :copy_config, :roles => :app do
        run "([ -f #{current_path}/config/#{stage}.sphinx.conf ] && cp #{current_path}/config/#{stage}.sphinx.conf #{release_path}/config/#{stage}.sphinx.conf) || true"
        run "[ -f #{release_path}/config/#{stage}.sphinx.conf ] || (cd #{release_path} && bundle exec rake ts:config RAILS_ENV=#{stage})"
      end
    end


#### Using [jammit](https://github.com/documentcloud/jammit)

For pre-asset-pipeline versions of Rails, this snippet will reprocess your assets with [jammit](https://github.com/documentcloud/jammit) only if necessary:

    ConditionalDeploy.register :jammit, :watchlist => ['public/images/embed', 'public/stylesheets', 'public/javascripts', 'public/assets', 'config/assets.yml'] do
      after 'deploy:symlink', 'deploy:rebuild_assets'
    end

#### Migrations

I've got <code>cap deploy</code> in muscle memory, and I used to find myself forgetting to run <code>cap deploy:migrations</code> until after I tested the new changes and found staging wasn't working right.  I now add the following code to my apps, so I never have to worry about it again:

    if ARGV.any?{|v| v['deploy:migrations']} # If running deploy:migrations
      # If there weren't any changes to migrations or the schema file, then abort the deploy
      ConditionalDeploy.register :unneeded_migrations, :none_match => ['db/schema.rb', 'db/migrate'] do
        abort "You're running migrations, but it doesn't look like you need to!"
      end
    else # If NOT running deploy:migrations
      # If there were changes to migration files, run migrations as part of the deployment
      ConditionalDeploy.register :forgotten_migrations, :any_match => ['db/schema.rb', 'db/migrate'], :msg => "Forgot to run migrations? It's cool, we'll do it for you." do
        after "deploy:update_code", "deploy:migrate"
      end
    end

Since I use it on every project, I've wrapped that logic up into this gem. To enable, just add `set :monitor_migrations, true`.

## Advanced Usage

If you need to force a particular conditional to run, you can do so via the environment.  Given the examples above, if you want to run the conditional named <code>whenever</code> even though config/schedule.rb hasn't been changed, just run <code>cap deploy RUN_WHENEVER=1</code>. Similarly, if you needed to skip the <code>whenever</code> conditional which would otherwise be run, you can use <code>cap deploy SKIP_WHENEVER=1</code>.

## License

Copyright &copy; 2014 [Deviantech, Inc.](http://www.deviantech.com) and released under the MIT license.
