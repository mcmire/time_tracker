
require 'units/models/spec_helper'
require 'tt/models/project'
require 'tt/models/task'
require 'tt/models/time_period'

describe TimeTracker::Models::TimePeriod do
  Models = TimeTracker::Models

  describe '.ended_today' do
    before do
      today = Date.today
      @start_of_today = Time.zone.local(today.year, today.month, today.day, 0, 0, 0)
      @end_of_today   = Time.zone.local(today.year, today.month, today.day, 23, 59, 59)
    end
    it "includes tasks ended today" do
      start_of_today_task = FactoryGirl.create(:time_period, :ended_at => @start_of_today)
      end_of_today_task = FactoryGirl.create(:time_period, :ended_at => @end_of_today)
      described_class.ended_today.to_a.must include(start_of_today_task)
      described_class.ended_today.to_a.must include(end_of_today_task)
    end
    it "excludes tasks ended in the past" do
      yesterday_task = FactoryGirl.create(:time_period, :ended_at => @start_of_today-1)
      described_class.ended_today.to_a.must_not include(yesterday_task)
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
      start_of_this_week_task = FactoryGirl.create(:time_period, :ended_at => @start_of_this_week)
      end_of_this_week_task = FactoryGirl.create(:time_period, :ended_at => @end_of_this_week)
      described_class.ended_this_week.to_a.must include(start_of_this_week_task)
      described_class.ended_this_week.to_a.must include(end_of_this_week_task)
    end
    it "excludes tasks ended in the past" do
      yesterday_task = FactoryGirl.create(:time_period, :ended_at => @start_of_this_week-1)
      described_class.ended_this_week.to_a.must_not include(yesterday_task)
    end
  end

  describe '#info' do
    before do
      @project = Models::Project.new(:name => "some project")
      @task = Models::Task.new(:project => @project, :number => "1", :name => "some task")
    end
    context "if :include_day not given" do
      it "excludes the day portion" do
        time_period = described_class.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 3, 33),
          :ended_at => Time.zone.local(2010, 1, 1, 11, 11)
        )
        time_period.info.must == [
          [
            Date.new(2010, 1, 1),
            ['', '3:33am', '', ' - ', '', '11:11am', '', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ]
        ]
      end
      it "creates fake time periods if starts_at is not the same day as ends_at" do
        time_period = described_class.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 3, 33),
          :ended_at => Time.zone.local(2010, 1, 3, 11, 11)
        )
        time_period.info.must == [
          [
            Date.new(2010, 1, 1),
            ['', '3:33am', '', ' - ', '(', '11:59pm', ')', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ],
          [
            Date.new(2010, 1, 2),
            ['(', '12:00am', ')', ' - ', '(', '11:59pm', ')', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ],
          [
            Date.new(2010, 1, 3),
            ['(', '12:00am', ')', ' - ', '', '11:11am', '', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ]
        ]
      end
      it "returns the arrays in reverse order if :reverse given" do
        time_period = described_class.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 3, 33),
          :ended_at => Time.zone.local(2010, 1, 3, 11, 11)
        )
        time_period.info(:reverse => true).must == [
          [
            Date.new(2010, 1, 3),
            ['(', '12:00am', ')', ' - ', '', '11:11am', '', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ],
          [
            Date.new(2010, 1, 2),
            ['(', '12:00am', ')', ' - ', '(', '11:59pm', ')', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ],
          [
            Date.new(2010, 1, 1),
            ['', '3:33am', '', ' - ', '(', '11:59pm', ')', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ]
        ]
      end
      it "removes fake time periods that don't satisfy the :where_date option" do
        time_period = described_class.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 3, 33),
          :ended_at => Time.zone.local(2010, 1, 3, 11, 11)
        )
        time_period.info(
          :where_date => lambda {|date| date == Date.new(2010, 1, 1) }
        ).must == [
          [
            Date.new(2010, 1, 1),
            ['', '3:33am', '', ' - ', '(', '11:59pm', ')', ' ', '[', '#1', ']', ' ', 'some project / some task']
          ]
        ]
      end
    end
    context "if :include_day given" do
      it "includes the day part" do
        time_period = described_class.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 3, 33),
          :ended_at => Time.zone.local(2010, 1, 3, 11, 11)
        )
        time_period.info(:include_day => true).must ==
          ['1/1/2010', ', ', '3:33am', ' - ', '1/3/2010', ', ', '11:11am', ' ', '[', '#1', ']', " ", 'some project / some task']
      end
      it "includes the day part even if days are the same" do
        time_period = described_class.new(
          :task => @task,
          :started_at => Time.zone.local(2010, 1, 1, 3, 33),
          :ended_at => Time.zone.local(2010, 1, 1, 11, 11)
        )
        time_period.info(:include_day => true).must ==
          ['1/1/2010', ', ', '3:33am', ' - ', '1/1/2010', ', ', '11:11am', ' ', '[', '#1', ']', " ", 'some project / some task']
      end
    end
    # the time stuff is tested in ruby_spec.rb
  end

  describe '#duration' do
    it "returns the seconds between started_at and ended_at" do
      period = described_class.new(
        :started_at => Time.zone.local(2010, 1, 1, 0, 0, 0),
        :ended_at => Time.zone.local(2010, 1, 1, 2, 30, 0)
      )
      period.duration.must == 9000
    end
  end

end
