require_relative '../spec_helper'
require 'tt/extensions/ruby'

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
end
