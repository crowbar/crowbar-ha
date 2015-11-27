name "pacemaker-remote"
description "Pacemaker remote cluster member"
run_list(
  "recipe[crowbar-pacemaker::remote]"
)
default_attributes()
override_attributes()
