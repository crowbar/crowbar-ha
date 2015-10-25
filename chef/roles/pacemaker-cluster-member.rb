name "pacemaker-cluster-member"
description "Pacemaker cluster member"
run_list(
         "recipe[crowbar-pacemaker::role_pacemaker_cluster_member]"
)
default_attributes()
override_attributes()
