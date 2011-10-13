name "ha_service-server"
description "Ha service Server Role"
run_list(
         "recipe[ha_service::api]",
         "recipe[ha_service::monitor]"
)
default_attributes()
override_attributes()

