#
# Cookbook Name:: crowbar-haproxy
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

# We're in the pacemaker barclamp, so we're using the pacemaker namespace

default[:pacemaker][:haproxy][:enabled] = false
default[:pacemaker][:haproxy][:agent] = "lsb:haproxy"
default[:pacemaker][:haproxy][:networks] = {}
default[:pacemaker][:haproxy][:op][:monitor][:interval] = "10s"
