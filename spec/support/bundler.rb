
# We have to load Bundler because we are using a git version of rr.
# However, we do not want to just `require 'bundler/setup'` because this
# requires that ALL of Bundler be loaded, which takes more time than we would
# like. All we really want is just enough of Bundler to be loaded to where the
# gems in our bundle are added to the load path, and nothing more. We can
# achieve this via `bundle install --standalone`. Read more here:
#
#   http://myronmars.to/n/dev-blog/2012/03/faster-test-boot-times-with-bundler-standalone
#
begin
  require 'yaml'
  bundle_config = YAML.load_file File.expand_path('../../../.bundle/config', __FILE__)
  if bundle_path = bundle_config['BUNDLE_PATH']
    bundle_path = File.expand_path(bundle_path)
  else
    puts "BUNDLE_PATH is not set."
    puts "Please run `bundle install --standalone` in order to run tests."
    exit 1
  end
  require "#{bundle_path}/bundler/setup"
rescue LoadError => e
  puts "#{e.class}: #{e.message} (#{e.backtrace[0]})"
  puts "Please run `bundle install --standalone` in order to run tests."
  exit 1
end
