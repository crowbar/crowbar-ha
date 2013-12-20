name "corosync-authkey-generator"
description "Generator of shared authkey for Corosync cluster"
# This has an identical run list to the corosync-cluster-member role,
# but can be used independently by the barclamp proposal's
# element_order attribute, to ensure that only one node is allowed
# to generate the authkey.  Once that is done, the other nodes
# can join the cluster using the same key.
run_list(
         "recipe[corosync::default]"
)
default_attributes()
override_attributes()
