#require 'spork'

lib_dir = File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.unshift(lib_dir)

#Spork.prefork do
  require 'pp'

  begin
    require 'bundler'
  rescue LoadError => e
    $stderr.puts "tt: Error loading Bundler: #{e}"
    require 'rubygems'
    require 'bundler'
  end
  Bundler.setup
  Bundler.require(:default, :test)

  #require 'spec'
  require 'spec/autorun'

  # Copied from Thor specs
  Kernel.module_eval do
    alias_method :must, :should
    alias_method :must_not, :should_not
    undef_method :should
    undef_method :should_not
  end

  $USE_TEST_DB = true

  class UnitsExampleGroup < Spec::ExampleGroup; end
  Spec::Example::ExampleGroupFactory.register(:units, UnitsExampleGroup)
  Spec::Runner.configure do |c|
    c.before(:each, :type => :units) do
      $RUNNING_TESTS = :units
    end
    c.before(:each, :type => :integration) do
      $RUNNING_TESTS = :integration
    end
  end

  #require 'mongo_mapper'
  #require 'thor'
  #require "parse_tree"
  #require "parse_tree_extensions"
  #require "ruby2ruby"
  #require "ruby-debug"

  Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f }

  Spec::Runner.configuration.include(ExampleMethods)
#end

#Spork.each_run do

#end

#Spork.each_run do
  require 'tt'

  require 'factory_girl'
  Factory.find_definitions

  Spec::Runner.configuration.before(:each) do
    TimeTracker.reload_config
  end
#end
