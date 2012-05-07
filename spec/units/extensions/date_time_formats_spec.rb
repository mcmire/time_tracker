
require_relative '../spec_helper'
require_relative '../../support/extras/timecop'
require 'tt/extensions/date_time_formats'

describe Date do
  describe '.to_s(:relative_date)' do
    specify "today" do
      Timecop.freeze Date.new(2010, 1, 1)
      Date.new(2010, 1, 1).to_s(:relative_date).must == 'Today'
    end
    specify "yesterday" do
      Timecop.freeze Date.new(2010, 1, 2)
      Date.new(2010, 1, 1).to_s(:relative_date).must == 'Yesterday'
    end
    specify "before yesterday" do
      Timecop.freeze Date.new(2010, 1, 1)
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
  describe '.to_s(:relative_date)' do
    specify "today" do
      Timecop.freeze Date.new(2010, 1, 1)
      Time.zone.local(2010, 1, 1).to_s(:relative_date).must == 'Today'
    end
    specify "yesterday" do
      Timecop.freeze Date.new(2010, 1, 2)
      Time.zone.local(2010, 1, 1).to_s(:relative_date).must == 'Yesterday'
    end
    specify "before yesterday" do
      Timecop.freeze Date.new(2010, 1, 1)
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
