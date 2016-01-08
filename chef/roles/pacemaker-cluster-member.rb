name "pacemaker-cluster-member"
description "Pacemaker cluster member"
run_list(
  "recipe[crowbar-pacemaker::default]",
  "recipe[crowbar-pacemaker::remote_delegator]"
)
default_attributes
override_attributes
