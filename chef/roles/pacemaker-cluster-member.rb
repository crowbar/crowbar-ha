name "pacemaker-cluster-member"
description "Pacemaker cluster member"
run_list(
         "recipe[pacemaker::default]"
)
default_attributes()
override_attributes()
