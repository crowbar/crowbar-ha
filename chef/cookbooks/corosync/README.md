Description
===========

This recipe provides a bare bones framework for Corosync.  To use,
assign the `corosync::master` recipe to a single server and the
`corosync::client` recipe to the cluster members.

The master node will generate the authkey for the cluster and store it
as a node attribute.  Clients will search for this attribute and use
it for cluster communication.
