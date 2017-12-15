require "spec_helper"

require_relative "../helpers/non_runnable_resource"
require_relative "../fixtures/alert"

describe "Chef::Provider::PacemakerAlert" do
  # for use inside examples:
  let(:fixture) { Chef::RSpec::Pacemaker::Config::ALERT_WITH_TO.dup }
  # for use outside examples (e.g. when invoking shared_examples)
  fixture = Chef::RSpec::Pacemaker::Config::ALERT_WITH_TO.dup

  def lwrp_name
    "alert"
  end

  include_context "a Pacemaker LWRP with artificially constructed resource"

  before(:each) do
    @resource.handler fixture.handler.dup
    @resource.receiver fixture.receiver.dup
  end

  def cib_object_class
    Pacemaker::Alert
  end

  shared_examples "an updateable resource" do
    include Chef::RSpec::Pacemaker::CIBObject

    it "should modify the alert if the resource is changed" do
      expected = fixture.dup
      expected.handler = "handlernew.sh"
      expected_configure_cmd_args = [expected.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.handler expected.handler
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

  it_should_behave_like "a non-runnable resource", fixture
end
