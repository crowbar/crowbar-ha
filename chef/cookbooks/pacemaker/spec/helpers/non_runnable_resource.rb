# Shared code used to test providers of non-runnable Chef resources
# representing Pacemaker CIB objects.  For example the provider for
# primitives is runnable (since primitives can be started and stopped)
# but constraints cannot.

require_relative "provider"
require_relative "shellout"

shared_examples "a non-runnable resource" do |fixture|
  include Chef::RSpec::Mixlib::ShellOut

  it_should_behave_like "all Pacemaker LWRPs", fixture

  describe ":delete action" do
    it "should delete a resource" do
      stub_shellout(fixture.definition_string)

      provider.run_action :delete

      cmd = "crm configure delete '#{fixture.name}'"
      expect(@chef_run).to run_execute(cmd)
      expect(@resource).to be_updated
    end
  end
end
