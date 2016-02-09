# Cookbook Name:: pacemaker
# Provider:: transaction
#
# Copyright:: 2015, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../libraries/pacemaker", this_dir)
require ::File.expand_path("../libraries/chef/mixin/pacemaker", this_dir)

action :commit_new do
  chef_resource_names = new_resource.cib_objects

  chef_resources = chef_resource_names.map do |chef_resource_name|
    run_context.resource_collection.lookup(chef_resource_name)
  end

  cmd = Mixlib::ShellOut.new("crm --display=plain configure show")
  cmd.environment["HOME"] = ENV.fetch("HOME", "/root")
  cmd.run_command

  existing_objects = begin
    cmd.error!
    # Only keep object names from the output; so remove continuation lines and
    # do some regexp magic.
    # Also deal with definitions like fencing_topology which have no name (the
    # regexp won't match, so we'll be good).
    cmd.stdout.lines.select { |l| l[0] !~ /\s/ }.map do |l|
      l.chomp.chomp("\\").gsub(/\A\S+ (\S+).*/, "\\1")
    end
  rescue StandardError => e
    Chef::Log.warn("Unable to get current list of CIB objects: #{e}")
    []
  end

  # The transaction should only create CIB objects which don't already exist.
  chef_resources_to_create = chef_resources.reject do |chef_resource|
    existing_objects.include? chef_resource.name
  end

  next if chef_resources_to_create.empty?

  cib_objects_to_create = chef_resources_to_create.map do |chef_resource|
    cib_object_class =
      chef_resource.provider_for_action(:nothing).cib_object_class
    cib_object_class.from_chef_resource(chef_resource)
  end

  transaction = ::Pacemaker::Transaction.new(
    name: new_resource.name,
    cib_objects: cib_objects_to_create
  )
  bash_code = <<-EOCODE.gsub(/^\s*\| /, "")
      | crm configure <<'EOF'
      | #{transaction.definition}
      | EOF
    EOCODE
  bash "crm configure #{new_resource.name}" do
    code bash_code
    action :nothing
  end.run_action(:run)
  new_resource.updated_by_last_action(true)
end
