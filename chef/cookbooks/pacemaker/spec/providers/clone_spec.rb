require "spec_helper"

require_relative "../helpers/runnable_resource"
require_relative "../fixtures/clone_resource"

describe "Chef::Provider::PacemakerClone" do
  # for use inside examples:
  let(:fixture) { Chef::RSpec::Pacemaker::Config::CLONE_RESOURCE.dup }
  # for use outside examples (e.g. when invoking shared_examples)
  fixture = Chef::RSpec::Pacemaker::Config::CLONE_RESOURCE.dup

  def lwrp_name
    "clone"
  end

  include_context "a Pacemaker LWRP with artificially constructed resource"

  before(:each) do
    @resource.rsc fixture.rsc.dup
    @resource.meta Hash[fixture.meta.dup]
  end

  def cib_object_class
    Pacemaker::Resource::Clone
  end

  shared_examples "an updateable resource" do
    include Chef::RSpec::Pacemaker::CIBObject

    it "should modify the clone if the resource is changed" do
      expected = fixture.dup
      expected.rsc = "primitive2"
      expected_configure_cmd_args = [expected.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.rsc expected.rsc
      end
    end
  end

  describe ":create action" do
    let(:action) { :create }
    it_should_behave_like "an updateable resource"
  end

  describe ":update action" do
    let(:action) { :update }
    it_should_behave_like "an updateable resource"
  end

  it_should_behave_like "a runnable resource", fixture
end
