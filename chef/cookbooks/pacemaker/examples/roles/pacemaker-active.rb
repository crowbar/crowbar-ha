name "pacemaker-active"
description "pacemaker active."

override_attributes(
  "pacemaker" => {
    "services" => {
    }
  }
  )

run_list(
  "recipe[pacemaker::master]",
  "recipe[pacemaker::services]"
  )
