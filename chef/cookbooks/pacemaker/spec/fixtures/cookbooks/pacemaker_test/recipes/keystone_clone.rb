this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../../../keystone_clone", this_dir)

pacemaker_clone Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE_NAME do
  clone = Chef::RSpec::Pacemaker::Config::KEYSTONE_CLONE

  rsc clone.rsc
  meta Hash[clone.meta]

  action :nothing
end
