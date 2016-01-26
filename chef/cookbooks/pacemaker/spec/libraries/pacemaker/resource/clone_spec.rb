require "spec_helper"

require_relative "../../../../libraries/pacemaker/resource/clone"
require_relative "../../../fixtures/clone_resource"
require_relative "../../../helpers/cib_object"
require_relative "../../../helpers/meta_examples"

describe Pacemaker::Resource::Clone do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::CLONE_RESOURCE.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::CLONE_RESOURCE_DEFINITION
  end

  def object_type
    "clone"
  end

  def pacemaker_object_class
    Pacemaker::Resource::Clone
  end

  def fields
    %w(name rsc)
  end

  it_should_behave_like "a CIB object"

  it_should_behave_like "with meta attributes"

  describe "#definition" do
    it "should return the definition string" do
      expect(fixture.definition).to eq(fixture_definition)
    end

    it "should return a short definition string" do
      clone = pacemaker_object_class.new("foo")
      clone.definition = \
        %!clone clone1 primitive1 meta globally-unique="true"!
      expect(clone.definition).to eq(<<'EOF'.chomp)
clone clone1 primitive1 \
         meta globally-unique="true"
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
  end
end
