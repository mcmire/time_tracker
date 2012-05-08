
require 'units/spec_helper'
require 'tt/commander'
require 'active_support/ordered_hash'

describe TimeTracker::Commander::Break do
  it "stores true/false without stringifying it" do
    e = described_class.new(true)
    e.message.must == true
  end
end

describe TimeTracker::Commander do
  before do
    @subclass = @metaclass = Class.new(TimeTracker::Commander)
  end

  def rescuing(exception_class)
    begin; yield; rescue exception_class => exception; end
    exception
  end

  describe '.command' do
    it "stores the given command in @commands" do
      @metaclass.command(:foo)
      @metaclass.commands.must include("foo")
    end
    it "also stores an argument string if that's given" do
      @metaclass.command(:foo, :args => "BAR")
      info = @metaclass.commands["foo"]
      info[:args].must == "BAR"
    end
    it "also stores a description if that's given" do
      @metaclass.command(:foo, :args => "BAR", :desc => "This command does something")
      info = @metaclass.commands["foo"]
      info[:args].must == "BAR"
      info[:desc].must == "This command does something"
    end
    it "also works if you don't supply an argument string" do
      @metaclass.command(:foo, :desc => "This command does something")
      info = @metaclass.commands["foo"]
      info[:desc].must == "This command does something"
    end
    #it "stores a list of subcommands if that's given" do
    #  @metaclass.command(:foo, :subcommands => %w(foo bar baz))
    #  info = @metaclass.commands["foo"]
    #  info[:subcommands].must == %w(foo bar baz)
    #end
    #it "sets @args to a joined list of subcommands if those are given and :args isn't" do
    #  @metaclass.command(:foo, :subcommands => %w(foo bar baz))
    #  info = @metaclass.commands["foo"]
    #  info[:args] = "{foo|bar|baz}"
    #end
  end

  describe '.command_list' do
    it "lists the defined commands sorted by name, along with their descriptions" do
      stub(@metaclass).commands {
        ActiveSupport::OrderedHash[
          :foo, {:args => "[BAR]", :desc => "This command does something"},
          :zing, {:desc => "Ying yang yoodle"},
          :pizzazz, {:args => "--wang [--wing]", :desc => "Razzmatazz"}
        ]
      }
      @metaclass.command_list.must smart_match([
        "foo [BAR]                   # This command does something",
        "pizzazz --wang [--wing]     # Razzmatazz",
        "zing                        # Ying yang yoodle"
      ])
    end
    it "handles really long usage strings" do
      stub(@metaclass).commands {
        ActiveSupport::OrderedHash[
          :baz, {:args => "--this --is --really --long --and --things", :desc => "This command does something"},
          :brah, {:desc => "Zomething zooo"}
        ]
      }
      @metaclass.command_list.must smart_match([
        "baz --this --is --really --long --and --things   # This command does something",
        "brah                                             # Zomething zooo"
      ])
    end
  end

  describe '.new' do
    it "stores the given program name in @program_name" do
      @commander = TimeTracker::Commander.new(:program_name => "program")
      @commander.program_name.must == "program"
    end
    it "defaults @program_name to $0" do
      prev_0 = $0
      $0 = "foobar"
      @commander = TimeTracker::Commander.new
      @commander.program_name.must == "foobar"
      $0 = prev_0
    end
    it "stores the given argv in @argv" do
      @commander = TimeTracker::Commander.new(:argv => ["foo"])
      @commander.argv.must == ["foo"]
    end
    it "defaults @argv to ARGV" do
      @commander = TimeTracker::Commander.new
      @commander.argv.must == ARGV
    end
    it "stores the given stdin in @stdin" do
      @commander = TimeTracker::Commander.new(:stdin => :stdin)
      @commander.stdin.must == :stdin
    end
    it "defaults @stdin to $stdin" do
      @commander = TimeTracker::Commander.new
      @commander.stdin.must == $stdin
    end
    it "stores the given stdout in @stdout" do
      @commander = TimeTracker::Commander.new(:stdout => :stdout)
      @commander.stdout.must == :stdout
    end
    it "defaults @stdout to $stdout" do
      @commander = TimeTracker::Commander.new
      @commander.stdout.must == $stdout
    end
    it "stores the given stderr in @stderr" do
      @commander = TimeTracker::Commander.new(:stderr => :stderr)
      @commander.stderr.must == :stderr
    end
    it "defaults @stderr to $stderr" do
      @commander = TimeTracker::Commander.new
      @commander.stderr.must == $stderr
    end
    it "inits @highline to a new Highline object" do
      @commander = TimeTracker::Commander.new
      @commander.highline.must be_a(::HighLine)
    end
  end

  describe '#execute!' do
    it "dispatches to the appropriate method in the given class" do
      @subclass.class_eval do
        command :foo
        def foo(one, two); end
      end
      cli = @subclass.new(:argv => ["foo", "bar", "baz"])
      mock(cli).foo("bar", "baz")
      cli.execute!
    end
    it "stores info about the current command while it is being executed" do
      @subclass.class_eval do
        command :foo, :args => "BAR BAZ", :desc => "Some command"
        def foo(one, two); end
      end
      cli = @subclass.new(:argv => ["foo", "bar", "baz"])
      stub(cli).foo
      cli.execute!
      cli.current_command.must == {:name => "foo", :args => "BAR BAZ", :desc => "Some command"}
    end
    it "bails if no method can be found" do
      @subclass.class_eval do
        command :bar, :desc => "Does the bar"
        def bar; end
      end
      cli = @subclass.new(:argv => ["foo", "bar", "baz"])
      e = rescuing(TimeTracker::Commander::Error) { cli.execute! }
      e.message.split(/\n/).must smart_match([
        %{Oops! "foo" isn't a command. Try one of these instead:},
        "",
        "  bar                         # Does the bar"
      ])
    end
    it "bails if method called with the wrong arguments" do
      @subclass.class_eval do
        command :foo, :args => "BAR", :desc => "Does the foo"
        def foo(one); end
      end
      cli = @subclass.new(:program_name => "program", :argv => ["foo", "bar", "baz"])
      e = rescuing(TimeTracker::Commander::Error) { cli.execute! }
      e.message.must == %{Oops! That isn't the right way to call "foo". Try this instead: program foo BAR}
    end
    #it "bails if method wasn't called with the right subcommand" do
    #  @subclass.class_eval do
    #    command :foo, :subcommands => %w(bar baz quux), :desc => "Does the foo"
    #    def foo(subcommand); end
    #  end
    #  cli = @subclass.new(:program_name => "program", :argv => ["foo", "zing"])
    #  e = rescuing(TimeTracker::Commander::Error) { cli.execute! }
    #  e.message.must == %/Oops! That isn't the right way to call "foo". Try this instead: program foo {bar|baz|quux}/
    #end
    it "bails if method wasn't marked as a command" do
      @subclass.class_eval do
        def foo(one, two); end
        command :bar, :desc => "Does the bar"
        def bar; end
      end
      cli = @subclass.new(:argv => ["foo", "bar", "baz"])
      e = rescuing(TimeTracker::Commander::Error) { cli.execute! }
      e.message.split(/\n/).must smart_match([
        %{Oops! "foo" isn't a command. Try one of these instead:},
        "",
        "  bar                         # Does the bar"
      ])
    end
  end

end
