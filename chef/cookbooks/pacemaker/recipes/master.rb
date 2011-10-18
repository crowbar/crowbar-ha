include_recipe "pacemaker::default"
require 'base64'

# Install haveged to create entropy so keygen doesn't take an hour

package "haveged"

# Make sure haveged is running (Should already be on ubuntu)

service "haveged" do
  supports :restart => true, :status => :true
  action :enable, :start
end
  

execute "Create authkey" do
  command "corosync-keygen"
  creates "/etc/corosync/authkey"
  action :run
  user "root"
  umask "0400"
end

# Read authkey (it's binary) into encoded format and save to chef server
ruby_block "Store authkey" do
  block do
    file = File.new('/etc/corosync/authkey', 'r')
    contents = ""
    file.each do |f|
      contents << f
    end
    packed = Base64.encode64(contents)
    node['corosync']['authkey'] = packed
    node.save
  end
end


