default[:drbd][:remote_host] = nil
default[:drbd][:disk] = nil
default[:drbd][:mount] = nil
default[:drbd][:fs_type] = "ext3"
default[:drbd][:dev] = "/dev/drbd0"
default[:drbd][:master] = false
default[:drbd][:port] = 7789
default[:drbd][:configured] = false

default[:drbd][:pacemaker][:agent] = "ocf:linbit:drbd"
default[:drbd][:pacemaker][:params][:drbd_resource] = "r0"
default[:drbd][:pacemaker][:op][:monitor][:interval] = "5s"
default[:drbd][:pacemaker][:op][:monitor][:role] = "Master"

default[:drbd][:pacemaker][:ms][:rsc_name] = "drbd"
default[:drbd][:pacemaker][:ms][:meta][:master_max] = "2"
default[:drbd][:pacemaker][:ms][:meta][:master_node_max] = "1"
default[:drbd][:pacemaker][:ms][:meta][:clone_max] = "2"
default[:drbd][:pacemaker][:ms][:meta][:clone_node_max] = "1"
default[:drbd][:pacemaker][:ms][:meta][:notify] = "true"
default[:drbd][:pacemaker][:ms][:meta][:resource_stickiness] = "100"
default[:drbd][:pacemaker][:ms][:meta][:target_role] = "Started"

case node.platform
when 'suse'
  default[:drbd][:packages] = %w(drbd-utils drbd-bash-completion drbd-kmp-default drbd-pacemaker drbd-udev)
else
  default[:drbd][:packages] = %w(drbd8-utils)
end
