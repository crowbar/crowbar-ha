this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../../../keystone_primitive", this_dir)

pacemaker_primitive Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE_NAME do
  primitive = Chef::RSpec::Pacemaker::Config::KEYSTONE_PRIMITIVE

  agent primitive.agent
  params Hash[primitive.params]
  meta Hash[primitive.meta]
  op Hash[primitive.op]

  action :nothing
end
