name "ha_service-passive"
description "Ha service Server Passive Role"
run_list(
         "recipe[ha_service::prepare]",
         "recipe[xfs]",
         "recipe[drbd::pair]",
         "recipe[ha_service::api]",
         "recipe[ha_service::monitor]"
)
default_attributes()
override_attributes(
   "drbd" => {
     "remote_host" => "d00-0c-29-33-0e-c4.greenman.org",
     "dev" => "/dev/drbd0",
     "disk" => "/dev/sdb1",
     "fs_type" => "xfs",
     "mount" => "/shared"
   },
   "ha_service" => {
     "raw_disk" => "/dev/sdb",
     "disk_partition" => "/dev/sdb1"
   }
)

