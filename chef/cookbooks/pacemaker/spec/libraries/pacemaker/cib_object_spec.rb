require "mixlib/shellout"

require "spec_helper"
require "helpers/crm_mocks"

require_relative "../../fixtures/keystone_primitive"

describe Pacemaker::CIBObject do
  include Chef::RSpec::Pacemaker::Mocks

  let(:fixture) { Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE.dup }

  #####################################################################
  # examples start here

  context "with no CIB object" do
    before(:each) do
      mock_nonexistent_cib_object(fixture.name)
    end

    describe "::from_name" do
      it "should return nil" do
        expect(::Pacemaker::CIBObject.from_name(fixture.name)).to eq(nil)
      end
    end

    describe ".exists?" do
      it "should return false" do
        expect(::Pacemaker::CIBObject.exists?(fixture.name)).to be_false
      end
    end
  end

  context "keystone primitive resource CIB object" do
    before(:each) do
      mock_existing_cib_object_from_fixture(fixture)
    end

    context "loaded from CIB" do
      let(:cib_object) { ::Pacemaker::CIBObject.from_name(fixture.name) }

      describe "#exists?" do
        it "should return true" do
          expect(cib_object.exists?).to be_true
        end
      end

      describe "#load_definition" do
        it "should retrieve cluster config" do
          expect(cib_object.definition).to eq(fixture.definition)
        end
      end

      describe "#type" do
        it "should return primitive" do
          expect(cib_object.type).to eq(:primitive)
        end
      end
    end

    describe ".exists?" do
      it "should return true" do
        expect(::Pacemaker::CIBObject.exists?(fixture.name)).to be_true
      end
    end
  end

  context "CIB object with unregistered type" do
    before(:each) do
      mock_existing_cib_object(fixture.name, "unregistered #{fixture.name} <definition>")
    end

    describe "::from_name" do
      it "should refuse to instantiate from any subclass" do
        expect { ::Pacemaker::CIBObject.from_name(fixture.name) }.
          to raise_error \
            "No subclass of Pacemaker::CIBObject was registered with type 'unregistered'"
      end
    end
  end

  context "invalid CIB object definition" do
    before(:each) do
      mock_existing_cib_object(fixture.name, "nonsense")
    end

    describe "#type" do
      it "should raise an error without a valid definition" do
        expect { ::Pacemaker::CIBObject.from_name(fixture.name) }.
          to raise_error(
            RuntimeError,
            "Couldn't extract CIB object type from 'nonsense'"
          )
      end
    end
  end
end
