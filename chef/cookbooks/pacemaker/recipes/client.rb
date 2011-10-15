include_recipe "pacemaker::default"
require 'base64'

# Don't need haveged, we're not generating certs

# Find the master node:
master = search(:node, "fqdn:#{node['pacemaker']['master']}")

log "Master node is #{master['ip_address']}"