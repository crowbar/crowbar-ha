#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: maintenance-mode
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

directory "/var/chef/handlers"

cookbook_file "pacemaker_maintenance_handlers" do
  path "/var/chef/handlers/pacemaker_maintenance_handlers.rb"
  source "pacemaker_maintenance_handlers.rb"
end

directory "/var/chef/libraries"

cookbook_file "maintenance_mode_helpers" do
  path "/var/chef/libraries/maintenance_mode_helpers.rb"
  source "maintenance_mode_helpers.rb"
end

bash "register Pacemaker maintenance handlers" do
  code <<'EOC'
    cat >> /etc/chef/client.rb <<EOF

require '/var/chef/handlers/pacemaker_maintenance_handlers'

pacemaker_start_handler = Chef::Pacemaker::StartHandler.new
start_handlers << pacemaker_start_handler # these fire at the beginning of a run

pacemaker_report_handler = Chef::Pacemaker::ReportHandler.new
report_handlers << pacemaker_report_handler # these fire at the end of a successful run

pacemaker_exception_handler = Chef::Pacemaker::ExceptionHandler.new
exception_handlers << pacemaker_exception_handler # these fire at the end of a failed run
EOF
EOC
  not_if "grep -q pacemaker_maintenance_handlers /etc/chef/client.rb"
end

loaded = \
  Chef::Handler.start_handlers .find { |h| h.class.to_s == 'Chef::Pacemaker::StartHandler'  } &&
  Chef::Handler.report_handlers.find { |h| h.class.to_s == 'Chef::Pacemaker::ReportHandler' }

if loaded
  Chef::Log.debug("Pacemaker maintenance handlers already installed")
else
  Chef::Log.info("Pacemaker maintenance handlers not installed; " +
                 "scheduling Chef config reload")
  ruby_block "reload_chef_client_config" do
    block { Chef::Config.from_file("/etc/chef/client.rb") }
    action :create
  end
end
