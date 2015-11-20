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
  action = nil
  mark = nil
  revision = nil

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

  if new_resource.revision.nil? && node.key?(cookbook_name)
    # Shortcut for integration in Crowbar; in the worst case, this is nil and
    # we'll hit the check a few lines later
    revision = node[cookbook_name]["crowbar-revision"]
  else
    revision = new_resource.revision
  end

  raise "Missing mark attribute" if mark.nil?
  raise "Missing revision attribute" if revision.nil?

  [action, mark, revision]
end

action :wait do
  action, mark, revision = get_options(new_resource)
  CrowbarPacemakerSynchronization.wait_for_mark_from_founder(node, mark, revision, new_resource.fatal, new_resource.timeout)
end

action :create do
  action, mark, revision = get_options(new_resource)
  CrowbarPacemakerSynchronization.set_mark_if_founder(node, mark, revision)
end

action :sync do
  action, mark, revision = get_options(new_resource)
  CrowbarPacemakerSynchronization.synchronize_on_mark(node, mark, revision, new_resource.fatal, new_resource.timeout)
end

action :guess do
  action, mark, revision = get_options(new_resource)
  raise "Cannot guess action based on resource name" if action.nil?

  if action == :wait
    CrowbarPacemakerSynchronization.wait_for_mark_from_founder(node, mark, revision, new_resource.fatal, new_resource.timeout)
  elsif action == :create
    CrowbarPacemakerSynchronization.set_mark_if_founder(node, mark, revision)
  elsif action == :sync
    CrowbarPacemakerSynchronization.synchronize_on_mark(node, mark, revision, new_resource.fatal, new_resource.timeout)
  end
end
