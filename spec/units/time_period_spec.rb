require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::TimePeriod do

  describe '.ended_today' do
    before do
      today = Date.today
      @start_of_today = Time.zone.local(today.year, today.month, today.day, 0, 0, 0)
      @end_of_today   = Time.zone.local(today.year, today.month, today.day, 23, 59, 59)
    end
    it "includes tasks ended today" do
      start_of_today_task = Factory(:time_period, :ended_at => @start_of_today)
      end_of_today_task = Factory(:time_period, :ended_at => @end_of_today)
      TimeTracker::TimePeriod.ended_today.to_a.must include(start_of_today_task)
      TimeTracker::TimePeriod.ended_today.to_a.must include(end_of_today_task)
    end
    it "excludes tasks ended in the past" do
      yesterday_task = Factory(:time_period, :ended_at => @start_of_today-1)
      TimeTracker::TimePeriod.ended_today.to_a.must_not include(yesterday_task)
    end
  end
  
  describe '.ended_this_week' do
    before do
      today = Date.today
      sunday = today - today.wday
      saturday = sunday + 6
      @start_of_this_week = Time.zone.local(sunday.year, sunday.month, sunday.day, 0, 0, 0)
      @end_of_this_week   = Time.zone.local(saturday.year, saturday.month, saturday.day, 23, 59, 59)
    end
    it "includes tasks ended this week" do
      start_of_this_week_task = Factory(:time_period, :ended_at => @start_of_this_week)
      end_of_this_week_task = Factory(:time_period, :ended_at => @end_of_this_week)
      TimeTracker::TimePeriod.ended_this_week.to_a.must include(start_of_this_week_task)
      TimeTracker::TimePeriod.ended_this_week.to_a.must include(end_of_this_week_task)
    end
    it "excludes tasks ended in the past" do
      yesterday_task = Factory(:time_period, :ended_at => @start_of_this_week-1)
      TimeTracker::TimePeriod.ended_this_week.to_a.must_not include(yesterday_task)
    end
  end
  
  describe '#info' do
    #it "returns the correct string, right-aligning started_at to the specified width" do
    #  project = Factory.build(:project, :name => "some project")
    #  task = Factory.build(:task, :number => "1", :name => "some task")
    #  time_period = Factory.build(:time_period,
    #    :task => task,
    #    :ended_at => Time.zone.local(2010, 12, 12, 12, 12)
    #  )
    #  time1 = Object.new
    #  time2 = Object.new
    #  
    #  stub(time1).to_s(:simpler_date) { "x" * 4 }
    #  stub(time_period).started_at { time1 }
    #  stub(time2).to_s(:simpler_date) { "x" * 20 }
    #  stub(time_period).ended_at { time2 }
    #  time_period.info(:right_align => 20).must == "                xxxx - xxxxxxxxxxxxxxxxxxxx some task [#1] (in some project)"
    #  
    #  stub(time1).to_s(:simpler_date) { "x" * 11 }
    #  stub(time_period).started_at { time1 }
    #  stub(time2).to_s(:simpler_date) { "x" * 13 }
    #  stub(time_period).ended_at { time2 }
    #  time_period.info(:right_align => 13).must == "  xxxxxxxxxxx - xxxxxxxxxxxxx some task [#1] (in some project)"
    #end
    #it "returns the correct string, right-aligning ended_at to a width of 20" do
    #  project = Factory.build(:project, :name => "some project")
    #  task = Factory.build(:task, :number => "1", :name => "some task")
    #  time_period = Factory.build(:time_period,
    #    :task => task,
    #    :started_at => Time.zone.local(2010, 12, 12, 12, 12)
    #  )
    #  time1 = Object.new
    #  time2 = Object.new
    #  
    #  stub(time2).to_s(:simpler_date) { "x" * 20 }
    #  stub(time_period).started_at { time2 }
    #  stub(time1).to_s(:simpler_date) { "x" * 4 }
    #  stub(time_period).ended_at { time1 }
    #  time_period.info(:right_align => 20).must == "xxxxxxxxxxxxxxxxxxxx -                 xxxx some task [#1] (in some project)"
    #  
    #  stub(time2).to_s(:simpler_date) { "x" * 13 }
    #  stub(time_period).started_at { time2 }
    #  stub(time1).to_s(:simpler_date) { "x" * 11 }
    #  stub(time_period).ended_at { time1 }
    #  time_period.info(:right_align => 13).must == "xxxxxxxxxxxxx -   xxxxxxxxxxx some task [#1] (in some project)"
    #end
    before do
      @project = TimeTracker::Project.new(:name => "some project")
      @task = TimeTracker::Task.new(:project => @project, :number => "1", :name => "some task")
    end
    context "if :include_date specified" do
      it "excludes the date for ended_at if it's the same as started_at" do
        time_period = TimeTracker::TimePeriod.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at => Time.zone.local(2010, 1, 1, 1, 0)
        )
        time_period.info(:include_date => true).must ==
          ['1/1/2010', ', ', '12:00am', ' - ', '', '', '1:00am', ' ', 'some task', ' ', '[#1] (in some project)']
      end
      it "includes the day for ended_at if it's not the same as started_at" do
        time_period = TimeTracker::TimePeriod.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at => Time.zone.local(2010, 1, 2, 1, 0)
        )
        time_period.info(:include_date => true).must ==
          ['1/1/2010', ', ', '12:00am', ' - ', '1/2/2010', ', ', '1:00am', ' ', 'some task', ' ', '[#1] (in some project)']
      end
    end
    context "if :include_date not specified" do
      it "excludes the day for started_at and ended_at if they're both on the same day" do
        time_period = TimeTracker::TimePeriod.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at => Time.zone.local(2010, 1, 1, 1, 0)
        )
        time_period.info.must == 
          ['12:00am', ' - ', '1:00am', ' ', 'some task', ' ', '[#1] (in some project)']
      end
      it "still includes the day for ended_at if it's not the same as started_at" do
        time_period = TimeTracker::TimePeriod.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at => Time.zone.local(2010, 1, 2, 1, 0)
        )
        time_period.info.must ==
          ['1/1/2010', ', ', '12:00am', ' - ', '1/2/2010', ', ', '1:00am', ' ', 'some task', ' ', '[#1] (in some project)']
      end
    end
    # the time stuff is tested in ruby_spec.rb
  end
  
  describe '#duration' do
    it "returns the seconds between started_at and ended_at" do
      period = TimeTracker::TimePeriod.new(
        :started_at => Time.zone.local(2010, 1, 1, 0, 0, 0),
        :ended_at => Time.zone.local(2010, 1, 1, 2, 30, 0)
      )
      period.duration.must == 9000
    end
  end
  
end