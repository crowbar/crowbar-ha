require "spec_helper"

require_relative "../helpers/provider"
require_relative "../helpers/non_runnable_resource"
require_relative "../fixtures/colocation_constraint"

describe "Chef::Provider::PacemakerColocation" do
  # for use inside examples:
  let(:fixture) { Chef::RSpec::Pacemaker::Config::COLOCATION_CONSTRAINT.dup }
  # for use outside examples (e.g. when invoking shared_examples)
  fixture = Chef::RSpec::Pacemaker::Config::COLOCATION_CONSTRAINT.dup

  def lwrp_name
    "colocation"
  end

  include_context "a Pacemaker LWRP with artificially constructed resource"

  before(:each) do
    @resource.score fixture.score
    @resource.resources fixture.resources.dup
  end

  def cib_object_class
    Pacemaker::Constraint::Colocation
  end

  shared_examples "an updateable resource" do
    include Chef::RSpec::Pacemaker::CIBObject

    it "should accept resources provided in an Array" do
      new_resources = %w(rsc1)
      fixture.resources = new_resources
      expected_configure_cmd_args = [fixture.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.resources new_resources
      end
    end

    it "should modify the constraint if it has a different score" do
      new_score = "100"
      fixture.score = new_score
      expected_configure_cmd_args = [fixture.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.score new_score
      end
    end

    it "should modify the constraint if it has a resource added" do
      new_resource = "bar:Stopped"
      expected = fixture.dup
      expected.resources = expected.resources.dup + " " + new_resource
      expected_configure_cmd_args = [expected.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.resources expected.resources
      end
    end

    it "should modify the constraint if it has a resource added via an Array" do
      new_resource = "bar:Stopped"
      expected = fixture.dup
      expected.resources = expected.resources.dup.split + [new_resource]
      expected_configure_cmd_args = [expected.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.resources expected.resources
      end
    end

    it "should modify the constraint if it has a different resource" do
      new_resources = "bar:Started"
      fixture.resources = new_resources
      expected_configure_cmd_args = [fixture.reconfigure_command]
      test_modify(expected_configure_cmd_args) do
        @resource.resources new_resources
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
