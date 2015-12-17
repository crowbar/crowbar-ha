require_relative "../../libraries/pacemaker/transaction"
require_relative "keystone_primitive"
require_relative "keystone_clone"
require_relative "keystone_location"

# For those who don't know, keystone is the Identity component of the
# OpenStack project: http://docs.openstack.org/developer/keystone/

class Chef
  module RSpec
    module Pacemaker
      module Config
        KEYSTONE_TRANSACTION_NAME = "keystone clone"
        KEYSTONE_TRANSACTION = ::Pacemaker::Transaction.new(
          name: KEYSTONE_TRANSACTION_NAME,
          cib_objects: [
            KEYSTONE_PRIMITIVE.dup,
            KEYSTONE_CLONE.dup,
            KEYSTONE_LOCATION.dup
          ]
        )
        KEYSTONE_TRANSACTION_DEFINITION = <<"EOF"
#{KEYSTONE_PRIMITIVE_DEFINITION}
#{KEYSTONE_CLONE_DEFINITION}
#{KEYSTONE_LOCATION_DEFINITION}
EOF
      end
    end
  end
end
