require "spec_helper"

require_relative "../helpers/runnable_resource"
require_relative "../fixtures/keystone_primitive"

describe "Chef::Provider::PacemakerPrimitive" do
  # for use inside examples:
  let(:fixture) { Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE }
  # for use outside examples (e.g. when invoking shared_examples)
  fixture = Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE

  def lwrp_name
    "primitive"
  end

  include_context "a Pacemaker LWRP with artificially constructed resource"

  before(:each) do
    @resource.agent fixture.agent
    @resource.params Hash[fixture.params]
    @resource.meta Hash[fixture.meta]
    @resource.op Hash[fixture.op]
  end

  def cib_object_class
    Pacemaker::Resource::Primitive
  end

  include Chef::RSpec::Pacemaker::Mocks

  shared_examples "an updateable resource" do
    include Chef::RSpec::Pacemaker::CIBObject

    it "should modify the primitive if it has different params" do
      expected_configure_cmd_args = [
        %'--set-parameter os_password ' +
          '--parameter-value \$ne\!w\%pa\\\'ss\&wo\"rd',
        %'--delete-parameter os_tenant_name'
      ].map { |args| "crm_resource --resource #{fixture.name} #{args}" }
      test_modify(expected_configure_cmd_args) do
        new_params = Hash[fixture.params].merge(
          "os_password" => %{$ne!w%pa'ss&wo"rd})
        new_params.delete("os_tenant_name")
        @resource.params new_params
        @resource.meta Hash[fixture.meta].merge("target-role" => "Stopped")
      end
    end

    def assert_no_modifications(recipe_agent, existing_agent)
      @resource.name "vip"
      @resource.agent (recipe_agent)
      @resource.params({ "ip" => "192.168.138.84" })
      @resource.meta ({})
      @resource.op ({ "monitor" => { "interval" => "10s" }})

      # Set what crm configure show returns for the "existing" 'vip' primitive
      existing_definition = <<EOF.chomp
primitive vip #{existing_agent} \\
        params ip=192.168.138.84 \\
        meta \\
        op monitor interval=10s
EOF
      mock_existing_cib_object("vip", existing_definition)

      provider.run_action :create

      expect(@chef_run).not_to run_execute(/.*/)
      expect(@resource).not_to be_updated
    end

    it "should not modify primitive if crmsh drops ocf:heartbeat: prefix" do
      assert_no_modifications("ocf:heartbeat:IPaddr2", "IPaddr2")
    end

    it "should not modify primitive if recipe drops ocf:heartbeat: prefix" do
      assert_no_modifications("IPaddr2", "ocf:heartbeat:IPaddr2")
    end

    it "should modify the primitive if it has different meta" do
      expected_configure_cmd_args = [
        %'--set-parameter is-managed --parameter-value false --meta'
      ].map { |args| "crm_resource --resource #{fixture.name} #{args}" }
      test_modify(expected_configure_cmd_args) do
        @resource.params Hash[fixture.params]
        @resource.meta Hash[fixture.meta].merge("is-managed" => "false")
      end
    end

    it "should modify the primitive if it has different params and meta" do
      expected_configure_cmd_args = [
        %'--set-parameter os_password --parameter-value newpasswd',
        %'--delete-parameter os_tenant_name',
        %'--set-parameter is-managed --parameter-value false --meta'
      ].map { |args| "crm_resource --resource #{fixture.name} #{args}" }
      test_modify(expected_configure_cmd_args) do
        new_params = Hash[fixture.params].merge("os_password" => "newpasswd")
        new_params.delete("os_tenant_name")
        @resource.params new_params
        @resource.meta Hash[fixture.meta].merge("is-managed" => "false")
      end
    end

    it "should modify the primitive if it has different op values" do
      expected_configure_cmd_args = [
        fixture.reconfigure_command.gsub("60", "120")
      ]
      test_modify(expected_configure_cmd_args) do
        new_op = Hash[fixture.op]
        # Ensure we're not modifying our expectation as well as the input
        new_op["monitor"] = new_op["monitor"].dup
        new_op["monitor"]["timeout"] = "120"
        @resource.op new_op
      end
    end
  end

  describe ":update action" do
    let(:action) { :update }
    it_should_behave_like "an updateable resource"
  end

  describe ":create action" do
    let(:action) { :create }
    it_should_behave_like "an updateable resource"

    context "creation from scratch" do
      include_context "stopped resource"

      it "should create a primitive if it doesn't already exist" do
        # The first time, Mixlib::ShellOut needs to return an empty definition.
        # Then the resource gets created so the second time it needs to return
        # the definition used for creation.
        mock_nonexistent_cib_object(fixture.name)
        mock_existing_cib_object_from_fixture(fixture)

        provider.run_action :create

        expect(@chef_run).to run_execute(stopped_fixture.configure_command)
        expect(@resource).to be_updated
      end

      it "should barf if crm fails to create the primitive" do
        double1 = nonexistent_cib_object_double(fixture.name)
        double2 = shellout_double(
          command: fixture.configure_command,
          stderr: "ERROR: crm configure failed",
          exitstatus: 1
        )
        stub_shellouts(double1, double2)

        expect { provider.run_action :create }.to \
          raise_error(RuntimeError, "Failed to create #{fixture}")

        expect(@chef_run).to run_execute(stopped_fixture.configure_command)
        expect(@resource).not_to be_updated
      end

      # This scenario seems rather artificial and unlikely, but it doesn't
      # do any harm to test it.
      it "should barf if crm creates a primitive with empty definition" do
        mock_nonexistent_cib_object(fixture.name)
        mock_nonexistent_cib_object(fixture.name)

        expect { provider.run_action :create }.to \
          raise_error(RuntimeError, "Failed to create #{fixture}")

        expect(@chef_run).to run_execute(stopped_fixture.configure_command)
        expect(@resource).not_to be_updated
      end
    end

    it "should barf if the primitive is already defined with the wrong agent" do
      existing_agent = "ocf:openstack:something-else"
      definition = fixture.definition_string.sub(fixture.agent, existing_agent)
      mock_existing_cib_object(fixture.name, definition)

      expected_error = \
        "Existing #{fixture} has agent '#{existing_agent}' " \
        "but recipe wanted '#{@resource.agent}'"
      expect { provider.run_action :create }.to \
        raise_error(RuntimeError, expected_error)

      expect(@resource).not_to be_updated
    end
  end

  it_should_behave_like "a runnable resource", fixture
end
