#
# Cookbook Name:: Ha service
# Recipe:: setup
#

include_recipe "#{@cookbook_name}::common"

bash "tty linux setup" do
  cwd "/tmp"
  user "root"
  code <<-EOH
	mkdir -p /var/lib/ha_service/
	curl #{node[:ha_service][:tty_linux_image]} | tar xvz -C /tmp/
	touch /var/lib/ha_service/tty_setup
  EOH
  not_if do File.exists?("/var/lib/ha_service/tty_setup") end
end
