require "spec_helper"

require_relative "../../../../libraries/pacemaker/resource/ms"
require_relative "../../../fixtures/ms_resource"
require_relative "../../../helpers/cib_object"
require_relative "../../../helpers/meta_examples"

describe Pacemaker::Resource::MasterSlave do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::MS_RESOURCE.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::MS_RESOURCE_DEFINITION
  end

  def object_type
    "ms"
  end

  def pacemaker_object_class
    Pacemaker::Resource::MasterSlave
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
      ms = pacemaker_object_class.new("foo")
      ms.definition = \
        %!ms ms1 primitive1 meta globally-unique="true"!
      expect(ms.definition).to eq(<<'EOF'.chomp)
ms ms1 primitive1 \
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
