require_relative "../../libraries/pacemaker/constraint/location"

module Chef::RSpec
  module Pacemaker
    module Config
      KEYSTONE_LOCATION = \
        ::Pacemaker::Constraint::Location.new("l-keystone")
      KEYSTONE_LOCATION.rsc   = "keystone"
      KEYSTONE_LOCATION.score = "-inf"
      KEYSTONE_LOCATION.node  = "node1"
      KEYSTONE_LOCATION_DEFINITION = "location l-keystone keystone -inf: node1"
    end
  end
end
