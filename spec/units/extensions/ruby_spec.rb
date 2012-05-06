require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Date do
  describe '.to_s(:relative_date)' do
    specify "today" do
      stub(Date).today { Date.new(2010, 1, 1) }
      Date.new(2010, 1, 1).to_s(:relative_date).must == 'Today'
    end
    specify "yesterday" do
      stub(Date).today { Date.new(2010, 1, 2) }
      Date.new(2010, 1, 1).to_s(:relative_date).must == 'Yesterday'
    end
    specify "before yesterday" do
      stub(Date).today { Date.new(2010, 1, 1) }
      Date.new(2010, 1, 6).to_s(:relative_date).must == '1/6/2010'
    end
  end

  describe '.to_s(:mdy)' do
    specify "months is 1 digit, days is 1 digit" do
      Date.new(2010, 1, 1).to_s(:mdy).must == '1/1/2010'
    end
    specify "months is 1 digit, days is 2 digits" do
      Date.new(2010, 1, 12).to_s(:mdy).must == '1/12/2010'
    end
    specify "months is 2 digits, days is 1 digit" do
      Date.new(2010, 12, 1).to_s(:mdy).must == '12/1/2010'
    end
    specify "months is 2 digits, days is 2 digits" do
      Date.new(2010, 12, 12).to_s(:mdy).must == '12/12/2010'
    end
  end
end

describe Time do
  describe ".human_time_duration" do
    context "given a duration in seconds, returns a formatted string if..." do
      specify "the duration is less than a minute" do
        Time.human_time_duration(1).must == "1s"
        Time.human_time_duration(59).must == "59s"
      end
      specify "the duration is a minute or more but less than a hour" do
        Time.human_time_duration(60).must == "1m"
        Time.human_time_duration(3599).must == "59m"
      end
      specify "the duration is an hour or more but less than a day" do
        Time.human_time_duration(3600).must == "1h"
        Time.human_time_duration(86399).must == "23h:59m"
      end
      specify "the duration is a day or more" do
        Time.human_time_duration(86400).must == "1d"
        Time.human_time_duration(307380).must == "3d, 13h:23m"
      end
    end
  end

  describe '.to_s(:relative_date)' do
    specify "today" do
      stub(Date).today { Date.new(2010, 1, 1) }
      Time.zone.local(2010, 1, 1).to_s(:relative_date).must == 'Today'
    end
    specify "yesterday" do
      stub(Date).today { Date.new(2010, 1, 2) }
      Time.zone.local(2010, 1, 1).to_s(:relative_date).must == 'Yesterday'
    end
    specify "before yesterday" do
      stub(Date).today { Date.new(2010, 1, 1) }
      Time.zone.local(2010, 1, 6).to_s(:relative_date).must == '1/6/2010'
    end
  end

  describe '.to_s(:mdy)' do
    specify "months is 1 digit, days is 1 digit" do
      Time.zone.local(2010, 1, 1).to_s(:mdy).must == '1/1/2010'
    end
    specify "months is 1 digit, days is 2 digits" do
      Time.zone.local(2010, 1, 12).to_s(:mdy).must == '1/12/2010'
    end
    specify "months is 2 digits, days is 1 digit" do
      Time.zone.local(2010, 12, 1).to_s(:mdy).must == '12/1/2010'
    end
    specify "months is 2 digits, days is 2 digits" do
      Time.zone.local(2010, 12, 12).to_s(:mdy).must == '12/12/2010'
    end
  end

  describe '.to_s(:hms)' do
    specify 'midnight' do
      Time.zone.local(2010, 1, 1, 0, 0, 0).to_s(:hms).must == '12:00am'
    end
    specify 'noon' do
      Time.zone.local(2010, 1, 1, 12, 0, 0).to_s(:hms).must == '12:00pm'
    end
    specify 'before noon (1 digit)' do
      Time.zone.local(2010, 1, 1, 5, 0, 0).to_s(:hms).must == '5:00am'
    end
    specify 'before noon (2 digits)' do
      Time.zone.local(2010, 1, 1, 10, 0, 0).to_s(:hms).must == '10:00am'
    end
    specify 'after noon (1 digit)' do
      Time.zone.local(2010, 1, 1, 14, 0, 0).to_s(:hms).must == '2:00pm'
    end
    specify 'after noon (2 digits)' do
      Time.zone.local(2010, 1, 1, 22, 0, 0).to_s(:hms).must == '10:00pm'
    end
  end
end
