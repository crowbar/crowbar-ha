name "pacemaker-remote"
description "Pacemaker remote cluster member"
run_list("recipe[crowbar-pacemaker::role_pacemaker_remote]")
default_attributes
override_attributes
