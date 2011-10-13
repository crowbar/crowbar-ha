#
# Cookbook Name:: glance
# Recipe:: api
#
#

include_recipe "#{@cookbook_name}::common"

ha_service_service "api"

node[:ha_service][:monitor][:svcs] <<["ha_service-api"]

