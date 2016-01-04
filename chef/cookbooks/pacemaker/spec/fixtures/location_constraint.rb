require_relative "../../libraries/pacemaker/constraint/location"

class Chef
  module RSpec
    module Pacemaker
      module Config
        LOCATION_CONSTRAINT =
          ::Pacemaker::Constraint::Location.new("location1")
        LOCATION_CONSTRAINT.rsc   = "primitive1"
        LOCATION_CONSTRAINT.score = "-inf"
        LOCATION_CONSTRAINT.node  = "node1"
        LOCATION_CONSTRAINT.attrs_authoritative
        LOCATION_CONSTRAINT_DEFINITION = "location location1 primitive1 -inf: node1"
      end
    end
  end
end
