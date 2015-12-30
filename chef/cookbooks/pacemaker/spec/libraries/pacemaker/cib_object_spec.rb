require "mixlib/shellout"

require "spec_helper"
require "helpers/crm_mocks"

require_relative "../../fixtures/keystone_primitive"

describe Pacemaker::CIBObject do
  include Chef::RSpec::Pacemaker::Mocks

  let(:cib_object) { Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE.dup }

  #####################################################################
  # examples start here

  context "with no CIB object" do
    before(:each) do
      mock_nonexistent_cib_object(cib_object.name)
    end

    describe "#load_definition" do
      it "should return nil" do
        cib_object.load_definition
        expect(cib_object.definition).to eq(nil)
      end
    end

    describe "#exists?" do
      it "should return false" do
        cib_object.load_definition
        expect(cib_object.exists?).to be_false
      end
    end

    describe ".exists?" do
      it "should return false" do
        expect(::Pacemaker::CIBObject.exists?(cib_object.name)).to be_false
      end
    end
  end

  context "keystone primitive resource CIB object" do
    before(:each) do
      mock_existing_cib_object_from_fixture(cib_object)
    end

    context "with definition loaded" do
      before(:each) do
        cib_object.load_definition
      end

      describe "#exists?" do
        it "should return true" do
          expect(cib_object.exists?).to be_true
        end
      end

      describe "#load_definition" do
        it "should retrieve cluster config" do
          expect(cib_object.definition).to eq(cib_object.definition_string)
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
        expect(::Pacemaker::CIBObject.exists?(cib_object.name)).to be_true
      end
    end
  end

  context "CIB object with unregistered type" do
    before(:each) do
      mock_existing_cib_object(cib_object.name, "unregistered #{cib_object.name} <definition>")
    end

    describe "::from_name" do
      it "should refuse to instantiate from any subclass" do
        expect {
          Pacemaker::CIBObject.from_name(cib_object.name)
        }.to raise_error "No subclass of Pacemaker::CIBObject was registered with type 'unregistered'"
      end
    end
  end

  context "invalid CIB object definition" do
    before(:each) do
      mock_existing_cib_object(cib_object.name, "nonsense")
    end

    describe "#type" do
      it "should raise an error without a valid definition" do
        expect { cib_object.load_definition }.to \
          raise_error(RuntimeError, "Couldn't extract CIB object type from 'nonsense'")
      end
    end
  end
end
