require "spec_helper"

require_relative "../../../../libraries/pacemaker/constraint/order"
require_relative "../../../fixtures/order_constraint"
require_relative "../../../helpers/cib_object"

describe Pacemaker::Constraint::Order do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::ORDER_CONSTRAINT.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::ORDER_CONSTRAINT_DEFINITION
  end

  def object_type
    "order"
  end

  def pacemaker_object_class
    Pacemaker::Constraint::Order
  end

  def fields
    %w(name score ordering)
  end

  it_should_behave_like "a CIB object"

  describe "#definition" do
    it "should return the definition string" do
      expect(fixture.definition).to eq(fixture_definition)
    end

    it "should return a short definition string" do
      order = pacemaker_object_class.new("foo")
      order.definition = \
        %!order order1 Mandatory: rsc1 rsc2!
      expect(order.definition).to eq(<<'EOF'.chomp)
order order1 Mandatory: rsc1 rsc2
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

    it "should parse the ordering" do
      expect(@parsed.ordering).to eq(fixture.ordering)
    end
  end
end
