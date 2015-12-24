name "hawk-server"
description "Hawk web server"
run_list(
         "recipe[hawk::server]"
)
default_attributes
override_attributes
