include_recipe "pacemaker::default"

require 'base64'

authkey = ""

# Find the master node:
if !File.exists?("/etc/corosync/authkey")
  master = search(:node, "corosync:authkey")
  if master.nil? or (master.length > 1)
    Chef::Application.fatal! "You must have one node with the pacemaker::master recipe in their run list to be a client."
  end
  Chef::Log.info "Found pacemaker::master node: #{master[0].name}"
  authkey = Base64.decode64(master[0]['corosync']['authkey'])
end

# # Read authkey (it's binary) into encoded format and save to chef server
# ruby_block "Store authkey" do
#   block do
#     file = File.new('/etc/corosync/authkey', 'r')
#     contents = ""
#     file.each do |f|
#       contents << f
#     end
#     packed = Base64.encode64(contents)
#     node.set_unless['corosync']['authkey'] = packed
#     node.save
#   end
#   action :nothing
#   subscribes :run, resources(:execute => "corosync-keygen"), :immediately
# end




file "/etc/corosync/authkey" do
  not_if {File.exists?("/etc/corosync/authkey")}
  content authkey
  owner "root"
  mode "0400"
  action :create
end
