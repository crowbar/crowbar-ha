DESCRIPTION
===========

Installs pacemaker and corosync.

This cookbook handles the creation of a pacemaker cluster with Corosync as the
transfer layer.

A pacemaker cluster consists of one master node, and one or more client nodes.

HA services have a VIP (Virtual IP address) that "floats" between nodes. This address
will only be active on one node at a time, and is managed by pacemaker.

In order for this to work, we need to set ip_nonlocal_bind on each node:

echo 1 > /proc/sys/net/ipv4/ip_nonlocal_bind

Also, the services being managed (haproxy, httpd, whatever) will be managed by
pacemaker. So, we need to be able to "trick" the other recipes configuring those
services into NOT actually starting/maintaining the services in a running state.
They will be started only on the active node, so the running status of the services
will float along with the VIP

What we expect to be able to do:

# Install a pacemaker cluster
## Create the corosync cert on the master node
## Store the cert for use by the clients
# Set up a VIP for the HA services (set via attribute)
# Manage HA services by pacemaker.
## Services will be listed as attributes in a hash
## Service name will be the key of the hash
## Relevant data required will be values under the service name

Example:

default[pacemaker][services] => {
	"mysqld" => {
    "vip" => "10.0.111.5",
    "active" => "10.0.111.2",
    "passive" => ["10.0.111.3"]
	},
	"apache2" => {}
}


Currently, the only configurable attribute is the master node. The value for this attribute MUST
be the FQDN of the node designated as the pacemaker cluster master. We store configuration data
as node attributes (generated at the time of convergence) on this node, and the other
cluster members read this via chef search. So get the FQDN right!

Resource/Provider
=================
pacemaker_service
---------------
LWRP for managing services with Pacemaker. Pacemaker will control the services for the node transparently, while other recipes will continue to believe they are managing that service. This is done by removing the init script and symlinking it to /bin/true while Pacemaker actually handles the script (this needs to be sorted out).

# Actions
- :create: Have Pacemaker manage the service.
- :remove: Have the service to manage itself.

# Attribute Parameters
- service: name of the service to manage with pacemaker. Name attribute.
- vip: virtual IP address to map to the service.
- active: whether this node is the 'active' node. Defaults to `false` for the 'passive' node.
- path: path to init script if it does not path to '/etc/init.d/SERVICE'. (optional)

# Examples
    # add the mysqld service
    pacemaker_service "mysqld" do
      vip "10.0.111.5"
      active true
      action :create
    end

LICENSE AND AUTHOR
==================

Author:: Keith Hudgins (<keith@dtosolutions.com>)
Author:: Matt Ray (<matt@opscode.com>)

Copyright 2011, Dell, Inc.
Copyright 2011, Opscode, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
