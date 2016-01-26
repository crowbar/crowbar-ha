require_relative "../../libraries/pacemaker/constraint/colocation"

class Chef
  module RSpec
    module Pacemaker
      module Config
        COLOCATION_CONSTRAINT =
          ::Pacemaker::Constraint::Colocation.new("colocation1")
        COLOCATION_CONSTRAINT.score = "inf"
        COLOCATION_CONSTRAINT.resources = "rsc1 rsc2"
        COLOCATION_CONSTRAINT.attrs_authoritative
        COLOCATION_CONSTRAINT_DEFINITION = "colocation colocation1 inf: rsc1 rsc2"
      end
    end
  end
end
