
# Prepare the disk for formatting
# Dig that crazy here document nesting, Scoob!
script "Format disk" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
sudo sfdisk #{node[:ha_service][:raw_disk]} -uM << EOF
;
EOF
  EOH
  
  not_if "test -f #{node[:ha_service][:raw_disk]}1"
end
