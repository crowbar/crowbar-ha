#
# Cookbook Name:: haproxy
# Recipe:: default
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

default[:haproxy][:platform][:package] = "haproxy"
default[:haproxy][:platform][:user] = "haproxy"
default[:haproxy][:platform][:group] = "haproxy"
default[:haproxy][:platform][:config_file] = "/etc/haproxy/haproxy.cfg"

default[:haproxy][:global][:maxconn] = 4096
default[:haproxy][:global][:bufsize] = 16384
default[:haproxy][:global][:chksize] = 16384

default[:haproxy][:defaults][:balance] = "roundrobin"

default[:haproxy][:stats][:enabled] = false
default[:haproxy][:stats][:address] = "0.0.0.0"
default[:haproxy][:stats][:port] = 8888

default[:haproxy][:sections] = {}
# Once the haproxy_loadbalancer has been invoked at least once, this
# attribute will look something like this:
#
#   default[:haproxy][:sections][:listen] = {
#     "keystone-service": {
#       "address": "0.0.0.0",
#       "port": 5000,
#       "use_ssl": false,
#       "mode": "http",
#       "servers": [ { "name": "node", "address": "192.168.124.10", "port": 5001 } ]
#     },
#     "keystone-admin": {
#       # similarly to above, but with different ports
#     },
#     # ...
#     # similarly for other services
#     # ...
#   }

