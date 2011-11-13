# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capistrano-conditional/version"

Gem::Specification.new do |s|
  s.name        = "capistrano-conditional"
  s.version     = Capistrano::Conditional::VERSION
  s.authors     = ["Kali Donovan"]
  s.email       = ["kali@deviantech.com"]
  s.homepage    = ""
  s.summary     = %q{Adds support for conditional deployment tasks}
  s.description = %q{Allows making tasks for git-based projects conditional based on the specific files to be deployed.}

  s.rubyforge_project = "capistrano-conditional"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "git"
  s.add_runtime_dependency "capistrano"
end
