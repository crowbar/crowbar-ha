require_relative "../../libraries/pacemaker/resource/primitive"

# For those who don't know, keystone is the Identity component of the
# OpenStack project: http://docs.openstack.org/developer/keystone/

class Chef
  module RSpec
    module Pacemaker
      module Config
        KEYSTONE_PRIMITIVE_NAME = "keystone"
        KEYSTONE_PRIMITIVE =
          ::Pacemaker::Resource::Primitive.new(KEYSTONE_PRIMITIVE_NAME)
        KEYSTONE_PRIMITIVE.agent = "ocf:openstack:keystone"
        KEYSTONE_PRIMITIVE.params = [
          ["os_password",    %{ad"min$pa&ss'wo%rd}],
          ["os_auth_url",    "http://node1:5000/v2.0"],
          ["os_username",    "admin"],
          ["os_tenant_name", "openstack"],
          ["user",           "openstack-keystone"]
        ]
        KEYSTONE_PRIMITIVE.meta = [
          ["is-managed", "true"]
        ]
        KEYSTONE_PRIMITIVE.op = [
          ["monitor", { "timeout" =>  "60", "interval" => "10s" }],
          ["start",   { "timeout" => "240", "interval" => "10s" }]
        ]
        KEYSTONE_PRIMITIVE_DEFINITION = <<'EOF'.chomp
primitive keystone ocf:openstack:keystone \
         params os_auth_url="http://node1:5000/v2.0" os_password="ad\"min$pa&ss'wo%rd" os_tenant_name="openstack" os_username="admin" user="openstack-keystone" \
         meta is-managed="true" \
         op monitor interval="10s" timeout="60" op start interval="10s" timeout="240"
EOF
      end
    end
  end
end
