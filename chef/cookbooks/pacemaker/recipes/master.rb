include_recipe "pacemaker::default"

require 'base64'

# Install haveged to create entropy so keygen doesn't take an hour
package "haveged"

service "haveged" do
  supports :restart => true, :status => :true
  action [:enable, :start]
end

#create authkey
execute "corosync-keygen" do
  creates "/etc/corosync/authkey"
  user "root"
  umask "0400"
  action :run
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
    node.set_unless['corosync']['authkey'] = packed
    node.save
  end
  action :nothing
  subscribes :run, resources(:execute => "corosync-keygen"), :immediately
end


