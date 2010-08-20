require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::CliMethods do
  before do
    @klass = Class.new { include TimeTracker::CliMethods }
  end
  
  describe '.command' do
    it "stores the given command in @commands" do
      @klass.command(:foo)
      @klass.commands.must include(:foo)
    end
    it "also stores an argument string if that was given" do
      @klass.command(:foo, :args => "BAR")
      @klass.commands[:foo].must == {:args => "BAR"}
    end
    it "also stores a description if that was given" do
      @klass.command(:foo, :args => "BAR", :desc => "This command does something")
      @klass.commands[:foo].must == {:args => "BAR", :desc => "This command does something"}
    end
    it "also works if you don't supply an argument string" do
      @klass.command(:foo, :desc => "This command does something")
      @klass.commands[:foo].must == {:desc => "This command does something"}
    end
  end
  
  describe '.command_list' do
    it "lists the defined commands, along with their descriptions" do
      stub(@klass).commands {
        ActiveSupport::OrderedHash[
          :foo, {:args => "[BAR]", :desc => "This command does something"},
          :zing, {:desc => "Ying yang yoodle"},
          :pizzazz, {:args => "--wang [--wing]", :desc => "Razzmatazz"}
        ]
      }
      @klass.command_list.must smart_match([
        "foo [BAR]                   # This command does something",
        "zing                        # Ying yang yoodle",
        "pizzazz --wang [--wing]     # Razzmatazz"
      ])
    end
    it "handles really long usage strings" do
      stub(@klass).commands {
        ActiveSupport::OrderedHash[
          :baz, {:args => "--this --is --really --long --and --things", :desc => "This command does something"},
          :brah, {:desc => "Zomething zooo"}
        ]
      }
      @klass.command_list.must smart_match([
        "baz --this --is --really --long --and --things   # This command does something",
        "brah                                             # Zomething zooo"
      ])
    end
  end
  
  describe '.new' do
    it "stores the given program name" do
      cli = @klass.new("tt")
      cli.program_name.must == "tt"
    end
    it "stores the given argv" do
      cli = @klass.new("tt", :argv => :argv)
      cli.argv.must == :argv
    end
    it "defaults argv to ARGV" do
      cli = @klass.new("tt")
      cli.argv.must == ARGV
    end
    it "stores the given stdin" do
      cli = @klass.new("tt", :stdin => :stdin)
      cli.stdin.must == :stdin
    end
    it "defaults @stdin to $stdin" do
      cli = @klass.new("tt")
      cli.stdin.must == $stdin
    end
    it "stores the given stdout" do
      cli = @klass.new("tt", :stdout => :stdout)
      cli.stdout.must == :stdout
    end
    it "defaults @stdout to $stdout" do
      cli = @klass.new("tt")
      cli.stdout.must == $stdout
    end
    it "stores the given stderr" do
      cli = @klass.new("tt", :stderr => :stderr)
      cli.stderr.must == :stderr
    end
    it "defaults @stderr to $stderr" do
      cli = @klass.new("tt")
      cli.stderr.must == $stderr
    end
  end
  
  describe '#dispatch' do
    before do
      @cli = @klass.new("tt", :argv => ["foo", "bar", "baz"])
    end
    it "dispatches to the appropriate method in the given class" do
      @klass.class_eval do
        command :foo
        def foo(one, two); end
      end
      mock(@cli).foo("bar", "baz")
      @cli.dispatch
    end
    it "bails if no method can be found" do
      @klass.class_eval do
        command :bar, :desc => "Does the bar"
        def bar; end
      end
      begin; @cli.dispatch; rescue TimeTracker::CliMethods::Error => e; end
      e.message.lines.must smart_match([
        %{Oops! "foo" isn't a command. Try one of these instead:},
        "",
        "  bar                         # Does the bar",
        ""
      ])
    end
    it "bails if method called with the wrong arguments" do
      @klass.class_eval do
        command :foo, :args => "BAR", :desc => "Does the foo"
        def foo(one); end
      end
      begin; @cli.dispatch; rescue TimeTracker::CliMethods::Error => e; end
      e.message.must == %{Oops! That isn't the right way to call "foo". Try this instead: tt foo BAR}
    end
    it "bails if method wasn't marked as a command" do
      @klass.class_eval do
        def foo(one, two); end
        command :bar, :desc => "Does the bar"
        def bar; end
      end
      begin; @cli.dispatch; rescue TimeTracker::CliMethods::Error => e; end
      e.message.lines.must smart_match([
        %{Oops! "foo" isn't a command. Try one of these instead:},
        "",
        "  bar                         # Does the bar",
        ""
      ])
    end
  end
end