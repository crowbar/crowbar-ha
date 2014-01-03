name "pacemaker-cluster-founder"
description "Pacemaker / Corosync cluster founder"
# This has an identical list of corosync recipes in its run list to
# the corosync-cluster-member role, but can be used independently by
# the barclamp proposal's element_order attribute, to ensure that only
# one node is allowed to generate the authkey and set up the cluster.
# Once that is done, the other nodes can join the cluster using the
# same key.
run_list(
         "recipe[corosync::default]",
         "recipe[pacemaker::setup]"
)
default_attributes()
override_attributes()
