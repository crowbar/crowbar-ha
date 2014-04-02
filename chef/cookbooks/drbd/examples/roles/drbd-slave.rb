name "drbd-slave"
description "DRBD slave role."

override_attributes(
  "drbd" => {
    "rsc" => {
      "shared" => {
        "remote_host" => "ha-node2",
        "disk" => "/dev/sdb1",
        "fs_type" => "xfs",
        "mount" => "/shared"
      }
    }
  }
  )

run_list(
  "recipe[xfs]",
  "recipe[drbd::default]",
  "recipe[drbd::resource]"
  )
