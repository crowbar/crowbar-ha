# Shared code used to test providers of non-runnable Chef resources
# representing Pacemaker CIB objects.  For example the provider for
# primitives is runnable (since primitives can be started and stopped)
# but constraints cannot.

require_relative "provider"
require_relative "crm_mocks"

shared_examples "a non-runnable resource" do |fixture|
  include Chef::RSpec::Pacemaker::Mocks

  it_should_behave_like "all Pacemaker LWRPs", fixture

  describe ":delete action" do
    it "should delete a resource" do
      mock_existing_cib_object_from_fixture(fixture)

      provider.run_action :delete

      cmd = "crm configure delete '#{fixture.name}'"
      expect(@chef_run).to run_execute(cmd)
      expect(@resource).to be_updated
    end
  end
end
