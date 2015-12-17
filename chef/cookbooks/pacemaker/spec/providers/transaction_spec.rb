require "spec_helper"

require_relative "../helpers/provider"
require_relative "../helpers/crm_mocks"
require_relative "../../libraries/pacemaker/transaction"
require_relative "../fixtures/keystone_primitive"
require_relative "../fixtures/keystone_clone"
require_relative "../fixtures/keystone_location"
require_relative "../fixtures/keystone_transaction"

describe "Chef::Provider::PacemakerClone" do
  def lwrp_name
    "transaction"
  end

  include_context "a Pacemaker LWRP"
  include Chef::RSpec::Pacemaker::Mocks

  # Override the default runlist for these tests
  let(:test_runlist) do
    [
      "pacemaker::default",
      "pacemaker_test::keystone_transaction",
    ]
  end

  describe ":commit_new action" do
    def resource
      @run_context.resource_collection.lookup(
        format("pacemaker_transaction[%s]",
                Chef::RSpec::Pacemaker::Config::KEYSTONE_TRANSACTION_NAME)
      )
    end

    let(:expected_resource_name) do
      "crm configure #{Chef::RSpec::Pacemaker::Config::KEYSTONE_TRANSACTION_NAME}"
    end

    it "should not commit anything for pre-existing objects" do
      stub_shellouts(
        existing_cib_object_double(
          Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_NAME,
          Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_DEFINITION
        ),
        existing_cib_object_double(
          Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_NAME,
          Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_DEFINITION
        ),
        existing_cib_object_double(
          Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_NAME,
          Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_DEFINITION
        )
      )

      converge

      expect(@chef_run).to_not run_bash(expected_resource_name)
      expect(resource).to_not be_updated
    end

    it "should commit all new objects in one go" do
      mock_nonexistent_cib_object \
        Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_NAME
      mock_nonexistent_cib_object \
        Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_NAME
      mock_nonexistent_cib_object \
        Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_NAME

      converge

      expect(@chef_run).to \
        run_bash(expected_resource_name). \
        with_code(<<-EOBASH.gsub(/^\s*\| /, ""))
          | crm configure <<'EOF'
          | #{Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_DEFINITION}
          | #{Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_DEFINITION}
          | #{Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_DEFINITION}
          | EOF
        EOBASH
      expect(resource).to be_updated
    end

    it "should commit only the missing objects in one go" do
      stub_shellouts(
        existing_cib_object_double(
          Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_NAME,
          Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_DEFINITION
        ),
        nonexistent_cib_object_double(
          Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_NAME,
        ),
        nonexistent_cib_object_double(
          Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_NAME,
        )
      )
      converge

      expect(@chef_run).to \
        run_bash(expected_resource_name). \
        with_code(<<-EOBASH.gsub(/^\s*\| /, ""))
          | crm configure <<'EOF'
          | #{Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_DEFINITION}
          | #{Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_DEFINITION}
          | EOF
        EOBASH
      expect(resource).to be_updated
    end
  end
end
