require "spec_helper"

require_relative "../helpers/runnable_resource"
require_relative "../fixtures/resource_group"

describe "Chef::Provider::PacemakerGroup" do
  # for use inside examples:
  let(:fixture) { Chef::RSpec::Pacemaker::Config::RESOURCE_GROUP.dup }
  # for use outside examples (e.g. when invoking shared_examples)
  fixture = Chef::RSpec::Pacemaker::Config::RESOURCE_GROUP.dup

  def lwrp_name
    "group"
  end

  include_context "a Pacemaker LWRP with artificially constructed resource"

  before(:each) do
    @resource.members fixture.members.dup
    @resource.meta Hash[fixture.meta.dup]
  end

  def cib_object_class
    Pacemaker::Resource::Group
  end

  describe ":create action" do
    include Chef::RSpec::Pacemaker::CIBObject

    it "should modify the group if it has a member resource added" do
      expected = fixture.dup
      expected.members = expected.members.dup + %w(resource3)
      expected_configure_cmd_args = [expected.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.members expected.members
      end
    end

    it "should modify the group if it has different member resources" do
      expected = fixture.dup
      expected.members = %w(resource1 resource3)
      expected_configure_cmd_args = [expected.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.members expected.members
      end
    end
  end

  it_should_behave_like "a runnable resource", fixture
end
