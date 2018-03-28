require "spec_helper"

require_relative "../../../libraries/pacemaker/alert"
require_relative "../../fixtures/alert"
require_relative "../../helpers/cib_object"
require_relative "../../helpers/meta_examples"

describe Pacemaker::Alert do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::ALERT.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::ALERT_DEFINITION
  end
  let(:fixture_with_to) { Chef::RSpec::Pacemaker::Config::ALERT_WITH_TO.dup }
  let(:fixture_definition_with_to) do
    Chef::RSpec::Pacemaker::Config::ALERT_DEFINITION_WITH_TO
  end

  let(:fixture_with_meta) { Chef::RSpec::Pacemaker::Config::ALERT_WITH_META.dup }
  let(:fixture_definition_with_meta) do
    Chef::RSpec::Pacemaker::Config::ALERT_DEFINITION_WITH_META
  end

  def object_type
    "alert"
  end

  def pacemaker_object_class
    Pacemaker::Alert
  end

  def fields
    %w(name handler receiver)
  end

  it_should_behave_like "a CIB object"

  it_should_behave_like "with meta attributes"

  describe "#definition" do
    it "should return the definition string" do
      expect(fixture.definition).to eq(fixture_definition)
    end

    it "should return the definition string (with to)" do
      expect(fixture_with_to.definition).to eq(fixture_definition_with_to)
    end

    it "should return the definition string (with meta)" do
      expect(fixture_with_meta.definition).to eq(fixture_definition_with_meta)
    end

    it "should return a short definition string" do
      alert = pacemaker_object_class.new("foo")
      alert.definition = "alert alert1 \"handler.sh\""
      expect(alert.definition).to eq("alert alert1 \"handler.sh\"")
    end

    it "should return a short definition string (with to)" do
      alert = pacemaker_object_class.new("foo")
      alert.definition = \
        %(alert alert1 "handler.sh" to receiver-id)
      expect(alert.definition).to eq(<<'PMCK'.chomp)
alert alert1 "handler.sh" \
         to receiver-id
PMCK
    end

    it "should return a short definition string (with meta)" do
      alert = pacemaker_object_class.new("foo")
      alert.definition = \
        %(alert alert1 "handler.sh" meta timeout=20s to receiver-id)
      expect(alert.definition).to eq(<<'PMCK'.chomp)
alert alert1 "handler.sh" \
         meta timeout="20s" \
         to receiver-id
PMCK
    end
  end

  describe "#parse_definition" do
    before(:each) do
      @parsed = pacemaker_object_class.new(fixture.name)
      @parsed.definition = fixture_definition

      @parsed_with_to = pacemaker_object_class.new(fixture_with_to.name)
      @parsed_with_to.definition = fixture_definition_with_to

      @parsed_with_meta = pacemaker_object_class.new(fixture_with_meta.name)
      @parsed_with_meta.definition = fixture_definition_with_meta

    end

    it "should parse the handler" do
      expect(@parsed.handler).to eq(fixture.handler)
      expect(@parsed_with_to.handler).to eq(fixture_with_to.handler)
      expect(@parsed_with_meta.handler).to eq(fixture_with_meta.handler)
    end

    it "should parse the receiver" do
      expect(@parsed.receiver).to eq(fixture.receiver)
      expect(@parsed_with_to.receiver).to eq(fixture_with_to.receiver)
      expect(@parsed_with_meta.receiver).to eq(fixture_with_meta.receiver)
    end

    it "should parse the meta" do
      expect(@parsed.meta).to eq(fixture.meta)
      expect(@parsed_with_to.meta).to eq(fixture_with_to.meta)
      expect(@parsed_with_meta.meta).to eq(fixture_with_meta.meta)
    end
  end
end
