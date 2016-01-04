this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../../../keystone_location", this_dir)

pacemaker_location Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION_NAME do
  location = Chef::RSpec::Pacemaker::Config::KEYSTONE_LOCATION

  rsc location.rsc
  score location.score
  lnode location.lnode

  action :nothing
end
