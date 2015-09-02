Corosync
===========

This cookbook configures and sets up Corosync. To use, assign
the `corosync::default` recipe to the cluster members.

The authkey is generated based on the following conditions:
- Is the node a founder node, this is checked by looking at
the attribute `node[:pacemaker][:founder]`
- Is there another founder node within the same cluster and
whether that particular node has already generated the authkey
- Does the current node have the authkey set as the attribute
`node[:corosync][:authkey]`

Clients then use the `node[:corosync][:authkey]` attribute for
for cluster communication.
