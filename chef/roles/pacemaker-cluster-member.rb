name "pacemaker-cluster-member"
description "Pacemaker cluster member"
run_list(
         "recipe[corosync::default]"
)
default_attributes()
override_attributes()
