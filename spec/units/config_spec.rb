require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Config do
  before do
    @coll = MongoMapper.database.collection("config")
  end
  describe '.collection' do
    it "returns the 'config' collection and caches the value" do
      config_klass = Class.new(TimeTracker::Config)
      mock(MongoMapper.database).collection("config") { :collection }.once
      ret = config_klass.collection
      ret = config_klass.collection
      ret.must == :collection
    end
  end
  describe '.find' do
    it "returns the first document in the config collection, if one exists, as a Config object" do
      @coll.save("foo" => 1)
      config = TimeTracker::Config.find
      config.must_not be_nil
      config["foo"].must == 1
    end
    it "returns a new Config object if the document hasn't been created yet" do
      config = TimeTracker::Config.find
      config.must_not be_nil
    end
  end
  describe '.new' do
    it "stores the given document" do
      TimeTracker::Config.new(:doc).doc.must == :doc
    end
  end
  describe '#save' do
    it "creates the document if it doesn't exist, setting the id to whatever the id is" do
      config = TimeTracker::Config.new("foo" => 1)
      config.save
      config["_id"].must_not be_nil
      doc = @coll.find_one()
      doc.must_not be_nil
      doc["_id"].must_not be_nil
      doc["foo"].must == 1
    end
    it "updates the document if it already exists" do
      @coll.save("foo" => 1)
      doc = @coll.find_one()
      config = TimeTracker::Config.new(doc)
      config["foo"] = "bar"
      config.save
      doc = @coll.find_one()
      doc["foo"].must == "bar"
    end
  end
  describe '#[]' do
    it "gets a key from the document" do
      config = TimeTracker::Config.new("foo" => 1)
      config["foo"].must == 1
    end
  end
  describe '#[]=' do
    it "sets a key on the document" do
      config = TimeTracker::Config.new("foo" => 1)
      config["foo"] = "bar"
      config.doc["foo"].must == "bar"
    end
  end
  describe '#update' do
    it "sets a key on the document, and then saves it" do
      @coll.save("foo" => 1)
      doc = @coll.find_one()
      config = TimeTracker::Config.new(doc)
      config.update("foo", "bar")
      doc = @coll.find_one()
      doc["foo"].must == "bar"
    end
  end
end
