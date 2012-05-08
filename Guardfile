
guard 'rspec', :version => 2, :all_on_start => false, :all_after_pass => false, :keep_failed => false, :cli => "--color -f documentation", :bundler => false do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/tt/(.+)\.rb$}) { |m| "spec/units/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb') { "spec" }
  watch(%r{^spec/support/(.+)\.rb$}) { "spec" }
end

