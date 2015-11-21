require_relative "../../libraries/pacemaker/constraint/location"

class Chef
  module RSpec
    module Pacemaker
      module Config
        KEYSTONE_LOCATION_NAME = "l-keystone"
        KEYSTONE_LOCATION =
          ::Pacemaker::Constraint::Location.new(KEYSTONE_LOCATION_NAME)
        KEYSTONE_LOCATION.rsc = "keystone"
        KEYSTONE_LOCATION.score = "-inf"
        KEYSTONE_LOCATION.lnode = "node1"
        KEYSTONE_LOCATION.attrs_authoritative
        KEYSTONE_LOCATION_DEFINITION = "location l-keystone keystone -inf: node1"
      end
    end
  end
end
