# Comments for the c-* settings come from
#   https://drbd.linbit.com/users-guide/s-configure-sync-rate.html
#   https://blogs.linbit.com/p/128/drbd-sync-rate-controller/
#   https://blogs.linbit.com/p/443/drbd-sync-rate-controller-2

# Set c-plan-ahead to approximately 10 times the RTT; so if ping from one node
# to the other says 200msec, configure 2 seconds (ie. a value of 20, as the
# unit is tenths of a second).
default["drbd"]["common"]["disk"]["c_plan_ahead"] = 20
# The resync controller tries to use up as much network and disk bandwidth as
# it can get, but no more than c-max-rate.
default["drbd"]["common"]["disk"]["c_max_rate"] = "15M"
# A good starting value for c-fill-target is BDPx3, where BDP is your bandwidth
# delay product on the replication link.
default["drbd"]["common"]["disk"]["c_fill_target"] = "5M"

default["drbd"]["common"]["net"]["shared_secret"] = "secret"

default["drbd"]["rsc"] = {}

default[:drbd][:pacemaker][:agent] = "ocf:linbit:drbd"
default[:drbd][:pacemaker][:params][:drbd_resource] = "r0"
default[:drbd][:pacemaker][:op][:monitor][:interval] = "5s"
default[:drbd][:pacemaker][:op][:monitor][:role] = "Master"

default[:drbd][:pacemaker][:ms][:rsc_name] = "drbd"
default[:drbd][:pacemaker][:ms][:meta][:master_max] = "1"
default[:drbd][:pacemaker][:ms][:meta][:master_node_max] = "1"
default[:drbd][:pacemaker][:ms][:meta][:clone_max] = "2"
default[:drbd][:pacemaker][:ms][:meta][:clone_node_max] = "1"
default[:drbd][:pacemaker][:ms][:meta][:notify] = "true"
default[:drbd][:pacemaker][:ms][:meta][:resource_stickiness] = "100"
default[:drbd][:pacemaker][:ms][:meta][:target_role] = "Started"

case node.platform
when "suse"
  default[:drbd][:packages] = %w(drbd-utils drbd-bash-completion drbd-kmp-default drbd-pacemaker drbd-udev)
else
  default[:drbd][:packages] = %w(drbd8-utils)
end
