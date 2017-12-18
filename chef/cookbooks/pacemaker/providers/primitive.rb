# Author:: Robert Choi
# Cookbook Name:: pacemaker
# Provider:: primitive
#
# Copyright:: 2013, Robert Choi
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

require "shellwords"

this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../libraries/pacemaker", this_dir)
require ::File.expand_path("../libraries/chef/mixin/pacemaker", this_dir)

include Chef::Mixin::Pacemaker::RunnableResource

action :create do
  name = new_resource.name

  if @current_resource_definition.nil?
    create_resource(name)
  else
    update_resource(name)
  end
end

action :update do
  unless @current_resource_definition.nil?
    update_resource(new_resource.name)
  end
end

action :delete do
  delete_runnable_resource
end

action :start do
  start_runnable_resource
end

action :stop do
  stop_runnable_resource
end

def cib_object_class
  ::Pacemaker::Resource::Primitive
end

def load_current_resource
  standard_load_current_resource
end

def resource_attrs
  [:agent, :params, :meta]
end

def create_resource(name)
  standard_create_resource
end

def op_defaults(node)
  return nil unless node[:pacemaker][:founder]
  return nil unless !node[:pacemaker].nil? && !node[:pacemaker][:op_defaults].nil?

  node[:pacemaker][:op_defaults].to_hash
end

def update_resource(name)
  ops = new_resource.op
  op_defaults = op_defaults(node)

  # If op_defaults is defined and not nil, set the value
  # otherwise remove it
  if !op_defaults.nil? &&
      op_defaults.key?("monitor") &&
      op_defaults["monitor"].key?("on-fail") &&
      !op_defaults["monitor"]["on-fail"].nil? &&
      !op_defaults["monitor"]["on-fail"].empty?

    if ops.is_a? Hash
      # Ops was defined as a Hash: we will skip the on-fail value
      # should it be declared. In a Hash there's no way to know the original
      # value, so it's either overwrite or skip.

    elsif ops.key?("monitor")
      # Ops was defined as a Chef::Node::Attribute. Store the on-fail
      # default value.
      ops["monitor"] = op_defaults["monitor"]
    end

  else
    if ops.is_a? Hash
      # Ops was defined as a Hash: we will skip the on-fail value
      # should it be declared. In a Hash there's no way to know the original
      # value, so it's either overwrite or skip.

    else
      # Ops was defined as a Chef::Node::Attribute. Store the on-fail
      # default value.

      # The 'current_normal' nesting level contains the values we have set
      # in the previous section. The 'current_default' nesting level contains
      # those values set in the recipe's attributes and are unchanged by
      # this code
      if ops.current_normal.key?("monitor")
        monitor = ops.current_normal.fetch("monitor")
        if monitor.key?("on-fail")
          monitor.delete("on-fail")
          ops["monitor"] = monitor
        end
      end
    end

  end

  current_agent = @current_resource.agent
  unless current_agent.include? ":"
    current_agent = "ocf:heartbeat:" + current_agent
  end

  new_agent = new_resource.agent
  unless new_agent.include? ":"
    new_agent = "ocf:heartbeat:" + new_agent
  end

  if current_agent != new_agent
    raise format(
      "Existing %s has agent '%s' but recipe wanted '%s'",
      @current_cib_object, @current_resource.agent, new_resource.agent
    )
  end

  maybe_modify_resource(name)
end

def maybe_modify_resource(name)
  deprecate_target_role

  Chef::Log.info "Checking existing #{@current_cib_object} for modifications"

  cmds = []

  desired_primitive = cib_object_class.from_chef_resource(new_resource)

  # We deprecated setting target-role values via the meta attribute, in favor
  # of :start/:stop actions on the resource. So this should not be relied upon
  # anymore, and it's safe to drop this if we want to.
  #
  # There is one racy case where this matters:
  #   - node1 and node2 try to create a primitive with the chef resource;
  #     on initial creation, we set target-role='Stopped' because we do not
  #     want to autostart primitives.
  #   - because they can't create it at the same time, node2 will fail on
  #     creation. If the chef resource is configured to retry, then node2 will
  #     then try to update the primitive (since it now exists); but the chef
  #     resource is not reloaded so still has target-role='Stopped'.
  #   - if node1 had also started the primitive before node2 retries the
  #     :create, then the target-role will be changed from 'Started' to
  #     'Stopped' with the update.
  #
  # This can result in a primitive not being started with [:create, :start].
  # Therefore, we just delete this deprecated bit from meta to avoid any issue.
  new_resource.meta.delete("target-role")
  desired_primitive.meta.delete("target-role")

  if desired_primitive.op_string != @current_cib_object.op_string
    Chef::Log.debug "op changed from [#{@current_cib_object.op_string}] to [#{desired_primitive.op_string}]"
    cmds = [desired_primitive.reconfigure_command]
  else
    maybe_configure_params(name, cmds, :params)
    maybe_configure_params(name, cmds, :meta)
  end

  cmds.each do |cmd|
    execute cmd do
      action :nothing
    end.run_action(:run)
  end

  new_resource.updated_by_last_action(true) unless cmds.empty?
end

def maybe_configure_params(name, cmds, data_type)
  configure_cmd_prefix = "crm_resource --resource #{name}"

  new_resource.send(data_type).each do |param, new_value|
    current_value = @current_resource.send(data_type)[param]
    # Value from recipe might be a TrueClass instance, but the same
    # value would be retrieved from the cluster resource as the String
    # "true".  So we force a string-wise comparison to adhere to
    # Postel's Law whilst minimising activity on the Chef client node.
    if current_value.to_s == new_value.to_s
      Chef::Log.info("#{name}'s #{param} #{data_type} didn't change")
    else
      Chef::Log.info("#{name}'s #{param} #{data_type} changed from #{current_value} to #{new_value}")
      cmd = configure_cmd_prefix +
        %' --set-parameter #{Shellwords.escape param}' +
        %' --parameter-value #{Shellwords.escape new_value}'
      cmd += " --meta" if data_type == :meta
      cmds << cmd
    end
  end

  @current_resource.send(data_type).each do |param, value|
    unless new_resource.send(data_type).key? param
      Chef::Log.info("#{name}'s #{param} #{data_type} was removed")
      cmd = configure_cmd_prefix + \
        %' --delete-parameter #{Shellwords.escape param}'
      cmd += " --meta" if data_type == :meta
      cmds << cmd
    end
  end
end
