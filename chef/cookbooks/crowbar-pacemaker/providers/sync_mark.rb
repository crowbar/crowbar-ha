#
# Copyright 2014, SUSE
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

def get_options resource
  sync_mark_config = begin
    Chef::DataBagItem.load("crowbar-config", "sync_mark")
  rescue Net::HTTPServerException
    {}
  end
  timeout = sync_mark_config.fetch("default_timeout", 60)
  action = nil
  mark = nil

  if new_resource.name.start_with? "wait-"
    mark = new_resource.name.gsub("wait-", "")
    action = :wait
  elsif new_resource.name.start_with? "create-"
    mark = new_resource.name.gsub("create-", "")
    action = :create
  elsif new_resource.name.start_with? "sync-"
    mark = new_resource.name.gsub("sync-", "")
    action = :sync
  end

  unless new_resource.mark.nil?
    mark = new_resource.mark
  end

  unless new_resource.timeout.nil?
    timeout = new_resource.timeout
  end

  raise "Missing mark attribute" if mark.nil?

  Chef::Log.info("Using timeout #{timeout} for sync_mark #{mark}")

  [action, mark, timeout]
end

action :wait do
  _, mark, timeout = get_options(new_resource)
  CrowbarPacemakerSynchronization.wait_for_mark_from_founder(
    node, mark, new_resource.fatal, timeout
  )
end

action :create do
  _, mark = get_options(new_resource)
  CrowbarPacemakerSynchronization.set_mark_if_founder(
    node, mark
  )
end

action :sync do
  _, mark, timeout = get_options(new_resource)
  CrowbarPacemakerSynchronization.synchronize_on_mark(
    node, mark, new_resource.fatal, timeout
  )
end

action :guess do
  action, mark, timeout = get_options(new_resource)
  raise "Cannot guess action based on resource name" if action.nil?

  if action == :wait
    CrowbarPacemakerSynchronization.wait_for_mark_from_founder(
      node, mark, new_resource.fatal, timeout
    )
  elsif action == :create
    CrowbarPacemakerSynchronization.set_mark_if_founder(
      node, mark
    )
  elsif action == :sync
    CrowbarPacemakerSynchronization.synchronize_on_mark(
      node, mark, new_resource.fatal, timeout
    )
  end
end
