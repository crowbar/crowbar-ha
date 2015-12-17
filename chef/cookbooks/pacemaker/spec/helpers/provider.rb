# Shared code used to test providers of CIB objects

require_relative "crm_mocks"
require_relative "cib_object"

shared_context "a Pacemaker LWRP" do
  let(:test_runlist) { "pacemaker::default" }

  before(:each) do
    stub_command("crm configure show smtp-notifications")
    stub_command("crm configure show cl-smtp-notifications")

    runner_opts = {
      step_into: ["pacemaker_" + lwrp_name]
    }
    @chef_run = ::ChefSpec::Runner.new(runner_opts)
    @node = @chef_run.node
  end

  def converge
    @chef_run.converge(*test_runlist)
    @run_context = @chef_run.run_context

    camelized_subclass_name = "Pacemaker" + lwrp_name.capitalize
    @resource_class = ::Chef::Resource.const_get(camelized_subclass_name)
    @provider_class = ::Chef::Provider.const_get(camelized_subclass_name)
  end
end

shared_context "a Pacemaker LWRP with artificially constructed resource" do
  include_context "a Pacemaker LWRP"

  before(:each) do
    converge
    @resource = @resource_class.new(fixture.name, @run_context)
  end

  let(:provider) { @provider_class.new(@resource, @run_context) }
end

module Chef::RSpec
  module Pacemaker
    module CIBObject
      include Chef::RSpec::Pacemaker::Mocks

      def test_modify(expected_cmds)
        yield

        mock_existing_cib_object_from_fixture(fixture)

        # action can be :create or :update
        provider.run_action action

        expected_cmds.each do |cmd|
          expect(@chef_run).to run_execute(cmd)
        end
        expect(@resource).to be_updated
      end
    end
  end
end

shared_examples "action on non-existent resource" do |action, cmd, expected_error|
  include Chef::RSpec::Pacemaker::Mocks

  it "should not attempt to #{action.to_s} a non-existent resource" do
    mock_nonexistent_cib_object(fixture.name)

    if expected_error
      expect { provider.run_action action }.to \
        raise_error(RuntimeError, expected_error)
    else
      provider.run_action action
    end

    expect(@chef_run).not_to run_execute(cmd)
    expect(@resource).not_to be_updated
  end
end

shared_examples "all Pacemaker LWRPs" do |fixture|
  describe ":delete action" do
    it_should_behave_like "action on non-existent resource", \
                          :delete, "crm configure delete #{fixture.name}", nil
  end
end
