# Shared code used to test providers of runnable Chef resources
# representing Pacemaker CIB objects.  For example the provider
# for primitives is runnable (since primitives can be started
# and stopped) but constraints cannot.

require_relative "provider"
require_relative "crm_mocks"

shared_context "stopped resource" do
  def stopped_fixture
    new_fixture = fixture.dup
    new_fixture.meta = fixture.meta.dup
    new_fixture.meta << ["target-role", "Stopped"]
    new_fixture
  end
end

shared_context "runnable resource" do |fixture|
  def expect_running(running)
    expect_any_instance_of(cib_object_class) \
      .to receive(:running?) \
      .and_return(running)
  end
end

shared_examples "a runnable resource" do |fixture|
  include_context "runnable resource"

  it_should_behave_like "all Pacemaker LWRPs", fixture

  include Chef::RSpec::Pacemaker::Mocks

  describe ":create action" do
    include_context "stopped resource"

    it "should not start a newly-created resource" do
      mock_nonexistent_cib_object(fixture.name)
      mock_existing_cib_object_from_fixture(fixture)

      provider.run_action :create

      expect(@chef_run).to run_execute(stopped_fixture.configure_command)
      expect(@resource).to be_updated
    end
  end

  describe ":delete action" do
    it "should not delete a running resource" do
      mock_existing_cib_object_from_fixture(fixture)
      expect_running(true)

      expected_error = "Cannot delete running #{fixture}"
      expect { provider.run_action :delete }.to \
        raise_error(RuntimeError, expected_error)

      cmd = "crm configure delete '#{fixture.name}'"
      expect(@chef_run).not_to run_execute(cmd)
      expect(@resource).not_to be_updated
    end

    it "should delete a non-running resource" do
      mock_existing_cib_object_from_fixture(fixture)
      expect_running(false)

      provider.run_action :delete

      cmd = "crm configure delete '#{fixture.name}'"
      expect(@chef_run).to run_execute(cmd)
      expect(@resource).to be_updated
    end
  end

  describe ":start action" do
    it_should_behave_like "action on non-existent resource", \
                          :start,
                          "crm --force --wait resource start #{fixture.name}", \
                          "Cannot start non-existent #{fixture}"

    it "should do nothing to a started resource" do
      mock_existing_cib_object_from_fixture(fixture)
      expect_running(true)

      provider.run_action :start

      cmd = "crm --force --wait resource start #{fixture.name}"
      expect(@chef_run).not_to run_execute(cmd)
      expect(@resource).not_to be_updated
    end

    it "should start a stopped resource" do
      config = fixture.definition_string.sub("Started", "Stopped")
      mock_existing_cib_object(fixture.name, config)
      expect_running(false)

      provider.run_action :start

      cmd = "crm --force --wait resource start '#{fixture.name}'"
      expect(@chef_run).to run_execute(cmd)
      expect(@resource).to be_updated
    end
  end

  describe ":stop action" do
    it_should_behave_like "action on non-existent resource", \
                          :stop,
                          "crm --force --wait resource stop #{fixture.name}", \
                          "Cannot stop non-existent #{fixture}"

    it "should do nothing to a stopped resource" do
      config = fixture.definition_string.sub("Started", "Stopped")
      mock_existing_cib_object(fixture.name, config)
      expect_running(false)

      provider.run_action :stop

      cmd = "crm --force --wait resource start #{fixture.name}"
      expect(@chef_run).not_to run_execute(cmd)
      expect(@resource).not_to be_updated
    end

    it "should stop a started resource" do
      mock_existing_cib_object_from_fixture(fixture)
      expect_running(true)

      provider.run_action :stop

      cmd = "crm --force --wait resource stop '#{fixture.name}'"
      expect(@chef_run).to run_execute(cmd)
      expect(@resource).to be_updated
    end
  end
end
