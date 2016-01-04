require "spec_helper"

require_relative "../../../../libraries/pacemaker/constraint/colocation"
require_relative "../../../fixtures/colocation_constraint"
require_relative "../../../helpers/cib_object"

describe Pacemaker::Constraint::Colocation do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::COLOCATION_CONSTRAINT.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::COLOCATION_CONSTRAINT_DEFINITION
  end

  def object_type
    "colocation"
  end

  def pacemaker_object_class
    Pacemaker::Constraint::Colocation
  end

  def fields
    %w(name score resources)
  end

  it_should_behave_like "a CIB object"

  describe "#new" do
    before(:each) do
      name = "foo"
      @resource_array = %w(rsc1 rsc2)
      @resource_string = @resource_array.join " "
      @colocation = pacemaker_object_class.new(name)
      @colocation.score = "-inf"
      @definition_string = "colocation %s %s: %s" %
        [name, @colocation.score, @resource_string]
    end

    it "should accept an String of resources" do
      @colocation.resources = @resource_string
      expect(@colocation.resources).to eq(@resource_string)
      @colocation.attrs_authoritative
      expect(@colocation.definition).to eq(@definition_string)
    end

    it "should accept an Array of resources" do
      @colocation.resources = @resource_array
      expect(@colocation.resources).to eq(@resource_string)
      @colocation.attrs_authoritative
      expect(@colocation.definition).to eq(@definition_string)
    end
  end

  describe "#definition" do
    it "should return the definition string" do
      expect(fixture.definition).to eq(fixture_definition)
    end

    it "should return a short definition string" do
      colocation = pacemaker_object_class.new("foo")
      colocation.definition = \
        %!colocation colocation1 -inf: rsc1 rsc2!
      expect(colocation.definition).to eq(<<'EOF'.chomp)
colocation colocation1 -inf: rsc1 rsc2
EOF
    end
  end

  describe "#parse_definition" do
    before(:each) do
      @parsed = pacemaker_object_class.new(fixture.name)
      @parsed.definition = fixture_definition
    end

    it "should parse the score" do
      expect(@parsed.score).to eq(fixture.score)
    end

    it "should parse the resources" do
      expect(@parsed.resources).to eq(fixture.resources)
    end
  end
end
