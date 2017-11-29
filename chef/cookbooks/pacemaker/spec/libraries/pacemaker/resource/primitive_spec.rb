require "spec_helper"

require_relative "../../../../libraries/pacemaker/resource/primitive"
require_relative "../../../fixtures/keystone_primitive"
require_relative "../../../helpers/cib_object"
require_relative "../../../helpers/meta_examples"

describe Pacemaker::Resource::Primitive do
  let(:fixture) { Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE.dup }
  let(:fixture_definition) do
    Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_DEFINITION
  end

  def object_type
    "primitive"
  end

  def pacemaker_object_class
    Pacemaker::Resource::Primitive
  end

  def fields
    %w(name agent params_string meta_string op_string)
  end

  it_should_behave_like "a CIB object"

  describe "#params_string" do
    it "should return empty string with nil params" do
      fixture.params = nil
      expect(fixture.params_string).to eq("")
    end

    it "should return empty string with empty params" do
      fixture.params = {}
      expect(fixture.params_string).to eq("")
    end

    it "should return a resource params string" do
      fixture.params = {
        "foo" => "bar",
        "baz" => "qux"
      }
      expect(fixture.params_string).to eq(%'params baz="qux" foo="bar"')
    end
  end

  describe "#op_string" do
    it "should return empty string with nil op" do
      fixture.op = nil
      expect(fixture.op_string).to eq("")
    end

    it "should return empty string with empty op" do
      fixture.op = {}
      expect(fixture.op_string).to eq("")
    end

    it "should return a resource op string" do
      fixture.op = {
        "monitor" => {
          "foo" => "bar",
          "baz" => "qux"
        }
      }
      expect(fixture.op_string).to eq(%(op monitor baz="qux" foo="bar" interval="0"))
    end

    it "should return a resource op string with multiple monitors" do
      fixture.op = {
        "monitor" => [
          {
            "foo" => "bar",
            "baz" => "qux"
          },
          {
            "oof" => "rab",
            "zab" => "xuq"
          }
        ]
      }
      expect(fixture.op_string).to eq(
        %(op monitor baz="qux" foo="bar" interval="0" op monitor interval="0" oof="rab" zab="xuq")
      )
    end
  end

  it_should_behave_like "with meta attributes"

  describe "#definition" do
    it "should return the definition string" do
      expect(fixture.definition).to eq(fixture_definition)
    end

    it "should return a short definition string" do
      primitive = pacemaker_object_class.new("foo")
      primitive.definition = \
        %!primitive foo ocf:heartbeat:IPaddr2 params foo="bar"!
      expect(primitive.definition).to eq(<<'EOF'.chomp)
primitive foo ocf:heartbeat:IPaddr2 \
         params foo="bar"
EOF
    end
  end

  describe "#quoted_definition" do
    it "should return the quoted definition string" do
      primitive = pacemaker_object_class.new("foo")
      primitive.definition = <<'EOF'.chomp
primitive foo ocf:openstack:keystone \
         params bar="foo\"bar$b!az\q%ux" bar2="ba'z\'qux"
EOF
      expect(primitive.quoted_definition).to eq(<<'EOF'.chomp)
'primitive foo ocf:openstack:keystone \
         params bar="foo\"bar$b!az\q%ux" bar2="ba'\''z\\'\''qux"'
EOF
    end
  end

  describe "#parse_definition" do
    before(:each) do
      @parsed = pacemaker_object_class.new(fixture.name)
      @parsed.definition = fixture_definition
    end

    it "should parse the agent" do
      expect(@parsed.agent).to eq(fixture.agent)
    end

    it "should parse all ops" do
      fixture.op.each do |op, param|
        expect(@parsed.op[op]).not_to be_nil
      end
    end
  end
end
