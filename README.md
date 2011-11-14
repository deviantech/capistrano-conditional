# capistrano-conditional

This gem extends capistrano deployments to allow certain tasks to only be run under certain conditions -- i.e. conditionally.

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

<code>capistrano-conditional</code> adds logic to be run before <code>cap deploy</code> or <code>cap deploy:migrations</code> that compares the local (to be deployed) code with the existing remote (currently deployed) code and lists all files that will be updated by the current deploy.  It then checks the list of conditional statements that you've provided and runs any that you want run -- e.g. if you're using [whenever](https://github.com/javan/whenever) and you only want to run the <code>deploy:update_crontab</code> task if <code>config/schedule.rb</code> has been changed, you'd add a block like this to your deploy.rb:

    ConditionalDeploy.register :whenever, :watchlist => 'config/schedule.rb' do
      after "deploy:symlink", "deploy:update_crontab"
    end

This example registers a conditional named "whenever" (names aren't programmatically important, but they're used to report what's going to be run at the beginning of each deploy).  The contents of the block will be run only if the list of changed files includes a path that matches <code>config/schedule.rb</code>.

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

    ConditionalDeploy.register :whenever, :watchlist => 'config/schedule.rb' do
      after "deploy:symlink", "deploy:update_crontab"
    end

    ConditionalDeploy.register :sphinx, :watchlist => ['db/schema.rb', 'db/migrate'] do
      before "deploy:update_code",  "thinking_sphinx:stop"
      before "deploy:start",        "thinking_sphinx:start"
      before "deploy:restart",      "thinking_sphinx:start"
    end

    ConditionalDeploy.register :jammit, :watchlist => ['public/images/embed', 'public/stylesheets', 'public/javascripts', 'public/assets', 'config/assets.yml'] do
      after 'deploy:symlink', 'deploy:rebuild_assets'
    end

    # Restart the resque workers unless the only changes were to static assets, views, or controllers.
    ConditionalDeploy.register(:resque, :unless => lambda { |changed| changed.all?{|f| f['public/'] || f['app/controllers/'] || f['app/views/'] } }) do
      before "deploy:restart", "resque:workers:restart"
    end
    
    # ... note that you still have to actually DEFINE the tasks laid out above (e.g. deploy:update_crontab)
    

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

Since I use it on ever project, I've wrapped that logic up in a single command:

    ConditionalDeploy.monitor_migrations(self)
  
## Advanced Usage

By default <code>capistrano-conditional</code> will abort the deployment if you have uncommited changes in your working directory.  You can skip this check on an individual run by setting the ALLOW_UNCOMMITED environment variable (e.g. <code>cap deploy ALLOW_UNCOMMITTED=1</code>).

If you need to force a particular conditional to run, you can also do that via the environment.  Given the examples above, if you want to run the conditional named <code>whenever</code> even though config/schedule.rb hasn't been changed, just run <code>code deploy RUN_WHENEVER=1</code>.

## License

Copyright &copy; 2011 [Deviantech, Inc.](http://www.deviantech.com) and released under the MIT license.

