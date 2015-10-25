name "hawk-server"
description "Hawk web server"
run_list(
         "recipe[crowbar-pacemaker::role_hawk_server]"
)
default_attributes()
override_attributes()
