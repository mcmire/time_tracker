require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Ruby extensions" do
  
  describe "Time.formatted_diff returns the difference, as a string, between times" do
    specify "that are less than a minute apart" do
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 1, 0, 0, 1)
      Time.formatted_diff(time2, time1).must == "1s"
      
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 1, 0, 0, 59)
      Time.formatted_diff(time2, time1).must == "59s"
    end
    specify "that are a minute or more but less than a hour apart" do
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 1, 0, 1, 0)
      Time.formatted_diff(time2, time1).must == "1m"
      
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 1, 0, 59, 59)
      Time.formatted_diff(time2, time1).must == "59m"
    end
    specify "that are an hour or more but less than a day apart" do
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 1, 1, 0, 0)
      Time.formatted_diff(time2, time1).must == "1h"
      
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 1, 23, 59, 59)
      Time.formatted_diff(time2, time1).must == "23h:59m"
    end
    specify "that are a day or more apart" do
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 2, 0, 0, 0)
      Time.formatted_diff(time2, time1).must == "1d"
      
      time1 = Time.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.local(2010, 1, 4, 13, 23, 18)
      Time.formatted_diff(time2, time1).must == "3d, 13h:23m"
    end
  end
  
end