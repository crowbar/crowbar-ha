require_relative "../../libraries/pacemaker/constraint/location"

class Chef
  module RSpec
    module Pacemaker
      module Config
        LOCATION_RULE_CONSTRAINT_NAME = "rulelocation1"
        LOCATION_RULE_CONSTRAINT_DEFINITION =
          "location #{LOCATION_RULE_CONSTRAINT_NAME} " \
          "primitive1 resource-discovery=exclusive " \
          "rule 0: OpenStack-role eq controller"

        LOCATION_RULE_CONSTRAINT =
          ::Pacemaker::Constraint::Location.new(LOCATION_RULE_CONSTRAINT_NAME)
        LOCATION_RULE_CONSTRAINT.definition =
          LOCATION_RULE_CONSTRAINT_DEFINITION
      end
    end
  end
end
