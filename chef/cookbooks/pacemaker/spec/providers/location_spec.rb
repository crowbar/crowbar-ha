require "spec_helper"

require_relative "../helpers/provider"
require_relative "../helpers/non_runnable_resource"
require_relative "../fixtures/location_constraint"
require_relative "../fixtures/location_rule_constraint"

describe "Chef::Provider::PacemakerLocation" do
  def lwrp_name
    "location"
  end

  include_context "a Pacemaker LWRP with artificially constructed resource"

  def cib_object_class
    Pacemaker::Constraint::Location
  end

  context "attribute-based" do
    # for use inside examples:
    let(:fixture) { Chef::RSpec::Pacemaker::Config::LOCATION_CONSTRAINT.dup }
    # for use outside examples (e.g. when invoking shared_examples)
    fixture = Chef::RSpec::Pacemaker::Config::LOCATION_CONSTRAINT.dup

    before(:each) do
      @resource.rsc fixture.rsc
      @resource.score fixture.score
      @resource.lnode fixture.lnode.dup
    end

    shared_examples "an updateable resource" do
      include Chef::RSpec::Pacemaker::CIBObject

      it "should modify the constraint if it has a different resource" do
        new_resource = "group2"
        fixture.rsc = new_resource
        expected_configure_cmd_args = [fixture.reconfigure_command]
        test_modify(expected_configure_cmd_args) do
          @resource.rsc new_resource
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

      it "should modify the constraint if it has a different node" do
        new_node = "node2"
        fixture.lnode = new_node
        expected_configure_cmd_args = [fixture.reconfigure_command]
        test_modify(expected_configure_cmd_args) do
          @resource.lnode new_node
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

  context "arbitrary string" do
    # for use inside examples:
    let(:fixture) { Chef::RSpec::Pacemaker::Config::LOCATION_RULE_CONSTRAINT.dup }
    # for use outside examples (e.g. when invoking shared_examples)
    fixture = Chef::RSpec::Pacemaker::Config::LOCATION_RULE_CONSTRAINT.dup

    before(:each) do
      @resource.definition fixture.definition
    end

    shared_examples "an updateable resource" do
      include Chef::RSpec::Pacemaker::CIBObject

      it "should modify the constraint if it has a different definition" do
        new_definition = fixture.definition + " foo"
        fixture.definition = new_definition
        expected_configure_cmd_args = [fixture.reconfigure_command]
        test_modify(expected_configure_cmd_args) do
          @resource.definition new_definition
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
end
