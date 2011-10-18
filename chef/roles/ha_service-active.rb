name "ha_service-server"
description "Ha service Server Active Role"
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
     "remote_host" => "ubuntu2-1004.vm",
     "disk" => "/dev/sdb1",
     "fs_type" => "xfs",
     "mount" => "/shared",
     "master" => true
   },
   "ha_service" => {
     "raw_disk" => "/dev/sdb",
     "disk_partition" => "/dev/sdb1"
   }
)

