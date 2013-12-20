name "corosync-cluster-member"
description "Corosync cluster member"
run_list(
         "recipe[corosync::default]"
)
default_attributes()
override_attributes()
