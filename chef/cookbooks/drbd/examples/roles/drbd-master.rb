name "drbd-master"
description "DRBD master role."

override_attributes(
  "drbd" => {
    "rsc" => {
      "shared" => {
        "remote_host" => "ha-node1",
        "disk" => "/dev/sdb1",
        "fs_type" => "xfs",
        "mount" => "/shared",
        "master" => true
      }
    }
  }
  )

run_list(
  "recipe[xfs]",
  "recipe[drbd::default]",
  "recipe[drbd::resource]"
  )
