name "pacemaker-remote-delegator"
description "Pacemaker remote node delegator"
run_list(
  "recipe[crowbar-pacemaker::remote_delegator]"
)
default_attributes()
override_attributes()
