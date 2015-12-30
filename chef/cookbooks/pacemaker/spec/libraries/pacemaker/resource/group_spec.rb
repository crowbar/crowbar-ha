require "spec_helper"

require_relative "../../../../libraries/pacemaker/resource/group"
require_relative "../../../fixtures/resource_group"
require_relative "../../../helpers/cib_object"
require_relative "../../../helpers/meta_examples"

describe Pacemaker::Resource::Group do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::RESOURCE_GROUP.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::RESOURCE_GROUP_DEFINITION
  end

  def object_type
    "group"
  end

  def pacemaker_object_class
    Pacemaker::Resource::Group
  end

  def fields
    %w(name members)
  end

  it_should_behave_like "a CIB object"

  it_should_behave_like "with meta attributes"

  describe "#definition" do
    it "should return the definition string" do
      expect(fixture.definition).to eq(fixture_definition)
    end

    it "should return a short definition string" do
      group = pacemaker_object_class.new("foo")
      group.definition = \
        %!group foo member1 member2 meta target-role="Started"!
      expect(group.definition).to eq(<<'EOF'.chomp)
group foo member1 member2 \
         meta target-role="Started"
EOF
    end
  end

  describe "#parse_definition" do
    before(:each) do
      @parsed = pacemaker_object_class.new(fixture.name)
      @parsed.definition = fixture_definition
    end

    it "should parse the members" do
      expect(@parsed.members).to eq(fixture.members)
    end
  end
end
