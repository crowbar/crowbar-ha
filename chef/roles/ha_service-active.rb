name "ha_service-active"
description "Ha service Server Active Role"
run_list(
         "recipe[ha_service::prepare]",
         "recipe[xfs]",
         "recipe[drbd::pair]",
         "recipe[ha_service::monitor]"
)
default_attributes()
override_attributes(
   "drbd" => {
     "remote_host" => "d00-0c-29-64-10-2c.greenman.org",
     "dev" => "/dev/sdb1",
     "fs_type" => "xfs",
     "mount" => "/shared",
     "master" => true
   },
   "ha_service" => {
     "raw_disk" => "/dev/sdb",
     "disk_partition" => "/dev/sdb1"
   }
)

