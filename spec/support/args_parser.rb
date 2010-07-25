#!/usr/bin/env ruby
require 'yaml'
require File.dirname(__FILE__) + '/integration_example_methods'
File.open(File.join(IntegrationExampleMethods.working_dir, "argv.yml"), "w") {|f| YAML.dump(ARGV, f) }