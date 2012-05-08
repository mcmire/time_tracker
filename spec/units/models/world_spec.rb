
require 'units/models/spec_helper'
require 'tt/models/world'

describe TimeTracker::Models::World do
  before do
    @coll = MongoMapper.database.collection("world")
  end
  describe '.collection' do
    it "returns the 'world' collection and caches the value" do
      world_klass = Class.new(described_class)
      mock(MongoMapper.database).collection("world") { :collection }.once
      ret = world_klass.collection
      ret = world_klass.collection
      ret.must == :collection
    end
  end
  describe '.find' do
    it "returns the first document in the world collection, if one exists, as a World object" do
      @coll.save("foo" => 1)
      world = described_class.find
      world.must_not be_nil
      world["foo"].must == 1
    end
    it "returns a new World object if the document hasn't been created yet" do
      world = described_class.find
      world.must_not be_nil
    end
  end
  describe '.reload' do
    it "re-runs the query to fetch the config data every time" do
      mock(described_class).find { :world }.twice
      ret = described_class.reload
      ret = described_class.reload
      ret.must == :world
    end
  end
  describe '.new' do
    it "stores the given document" do
      described_class.new(:doc).doc.must == :doc
    end
  end
  describe '#save' do
    it "creates the document if it doesn't exist, setting the id to whatever the id is" do
      world = described_class.new("foo" => 1)
      world.save
      world["_id"].must_not be_nil
      doc = @coll.find_one()
      doc.must_not be_nil
      doc["_id"].must_not be_nil
      doc["foo"].must == 1
    end
    it "updates the document if it already exists" do
      @coll.save("foo" => 1)
      doc = @coll.find_one()
      world = described_class.new(doc)
      world["foo"] = "bar"
      world.save
      doc = @coll.find_one()
      doc["foo"].must == "bar"
    end
  end
  describe '#[]' do
    it "gets a key from the document" do
      world = described_class.new("foo" => 1)
      world["foo"].must == 1
    end
  end
  describe '#[]=' do
    it "sets a key on the document" do
      world = described_class.new("foo" => 1)
      world["foo"] = "bar"
      world.doc["foo"].must == "bar"
    end
  end
  describe '#update' do
    it "sets a key on the document, and then saves it" do
      @coll.save("foo" => 1)
      doc = @coll.find_one()
      world = described_class.new(doc)
      world.update("foo", "bar")
      doc = @coll.find_one()
      doc["foo"].must == "bar"
    end
  end
end
