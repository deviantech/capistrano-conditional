# capistrano-conditional

This gem extends capistrano v3 deployments to allow certain tasks to only be run under certain conditions -- i.e. conditionally.

For capistrano v2 support, see version 0.1.0.


## Installation

Add to your Gemfile:

    group :development do
      gem 'capistrano-conditional', :require => false # <-- This is important!
    end

And then modify your Capfile to include this line:

    require "capistrano/conditional"

## Requirements

Your application must already be using capistrano for deployments, and (for now at least) you need to be using git.

## Usage

### Overview

<code>capistrano-conditional</code> adds logic to be run before <code>deploy:starting</code> that compares the to-be-deployed code with the existing remote (currently deployed) code and lists all files that will be updated by the current deploy.  It then checks the list of conditional statements that you've provided and runs any that match the conditions specified, which allows you to only run certain tasks when other conditions are met.  For instance, to add a logging statement to the capistrano output if any asset files have changed:

    ConditionalDeploy.configure(self) do |conditional|
      conditional.register :asset_announcement, :any_match => ['app/assets'] do |c|
        puts "Pointless alert: you're deploying an updated asset file!"
      end
    end


This example registers a conditional named "asset_announcements" (names aren't programmatically important, but they're used to report what's going to be run at the beginning of each deploy).  The contents of the block will be run only if the list of changed files includes a path that matches <code>add/assets</code>. For more useful tasks, keep reading.


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


### Skipping Tasks

A major change from Capistrano 2 to Capistrano 3 is that task definitions are now additive, so defining a new task doesn't overwrite the existing definition. Often we want to replace a task with a no-op when certain conditions match, however (e.g. skip compiling assets if none have changed since the previous deploy).  To help with this, CapistranoConditional adds a `skip_task` helper method on the context passed into the register block.  It clears out the existing definition of that method and, by default, replaces it with a `put` statement saying it's been skipped.

It accepts a hash of options, including `:silent` (if truthy, the put statement is skipped), `:message` (to customize the message to be displayed), and `:clear_hooks`, which will clear all existing before/after hooks on the named task as well as updating the task's definition itself.

For instance, using [whenever](https://github.com/javan/whenever), to only run the rake task updating the crontab if the schedule.rb has changed:

    ConditionalDeploy.configure(self) do |conditional|
      conditional.register :no_whenever, :none_match => 'config/schedule.rb' do |c|
        c.skip_task 'whenever:update_crontab'
      end
    end


### Example Usage - Asset Precompilation

    ConditionalDeploy.configure(self) do |conditional|
      asset_paths = ['/assets', 'Gemfile.lock', 'config/environments']
      conditional.register :skip_asset_precompilation, none_match: asset_paths do |c|
        c.skip_task 'deploy:compile_assets'
      end

      conditional.register :local_asset_precompilation, any_match: asset_paths do |c|
        c.skip_task 'deploy:compile_assets', silent: true

        task 'deploy:compile_assets' do
          # Logic here to precompile locally
        end
      end
    end





## Advanced Usage

If you need to force a particular conditional to run, you can do so via the environment.  Given the examples above, if you want to run the conditional named <code>whenever</code> even though config/schedule.rb hasn't been changed, just run <code>cap deploy RUN_WHENEVER=1</code>. Similarly, if you needed to skip the <code>whenever</code> conditional which would otherwise be run, you can use <code>cap deploy SKIP_WHENEVER=1</code>.

### Setting branches

By default, capistrano-conditional pics up the branch-to-be-deployed from the `:branch` setting used by capistrano multistage, or defaults to `HEAD`. To specify a different branch manually: `set :git_deploying, 'some/other/branch/name'`.

## License

Copyright &copy; 2014 [Deviantech, Inc.](http://www.deviantech.com) and released under the MIT license.
