require "capistrano-conditional/version"
require 'git'
require "capistrano-conditional/unit"
require "capistrano-conditional/deploy"

load File.expand_path("../../capistrano-conditional/tasks/integration.rake", __FILE__)