require "spec_helper"

require_relative "../../../../libraries/pacemaker/constraint/location"
require_relative "../../../fixtures/location_constraint"
require_relative "../../../fixtures/location_rule_constraint"
require_relative "../../../helpers/cib_object"

describe Pacemaker::Constraint::Location do
  def object_type
    "location"
  end

  def pacemaker_object_class
    Pacemaker::Constraint::Location
  end

  context "simple location constraint" do
    let(:fixture) { Chef::RSpec::Pacemaker::Config::LOCATION_CONSTRAINT.dup }
    let(:fixture_definition) do
      Chef::RSpec::Pacemaker::Config::LOCATION_CONSTRAINT_DEFINITION
    end

    def fields
      %w(name rsc score node)
    end

    it_should_behave_like "a CIB object"

    describe "#definition" do
      it "should return the definition string" do
        expect(fixture.definition).to eq(fixture_definition)
      end

      it "should return a short definition string" do
        location = pacemaker_object_class.new("foo")
        location.definition =
          %!location location1 primitive1 -inf: node1!
        expect(location.definition).to eq(<<'EOF'.chomp)
location location1 primitive1 -inf: node1
EOF
      end
    end

    describe "#parse_definition" do
      before(:each) do
        @parsed = pacemaker_object_class.new(fixture.name)
        @parsed.definition = fixture_definition
      end

      it "should parse the rsc" do
        expect(@parsed.rsc).to eq(fixture.rsc)
      end

      it "should parse the score" do
        expect(@parsed.score).to eq(fixture.score)
      end

      it "should parse the node" do
        expect(@parsed.node).to eq(fixture.node)
      end
    end
  end

  context "rule-based constraint" do
    let(:fixture) { Chef::RSpec::Pacemaker::Config::LOCATION_RULE_CONSTRAINT.dup }
    let(:fixture_definition) do
      Chef::RSpec::Pacemaker::Config::LOCATION_RULE_CONSTRAINT_DEFINITION
    end

    def fields
      %w(name definition)
    end

    describe "with arbitrary definition" do
      before(:each) do
        @obj = pacemaker_object_class.new(fixture.name)
        @obj.definition = fixture_definition
      end

      it "should return an unparsed definition string" do
        expect(@obj.definition).to eq(fixture_definition)
      end

      it "should not return a rsc attribute" do
        expect(@obj.rsc).to be_nil
      end

      it "should not return a score attribute" do
        expect(@obj.score).to be_nil
      end

      it "should not return a node attribute" do
        expect(@obj.node).to be_nil
      end
    end

    it_should_behave_like "a CIB object"
  end
end
