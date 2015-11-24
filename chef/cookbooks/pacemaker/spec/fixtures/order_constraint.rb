require_relative "../../libraries/pacemaker/constraint/order"

module Chef::RSpec
  module Pacemaker
    module Config
      ORDER_CONSTRAINT = \
        ::Pacemaker::Constraint::Order.new("order1")
      ORDER_CONSTRAINT.score = "Mandatory"
      ORDER_CONSTRAINT.ordering = "primitive1 clone1"
      ORDER_CONSTRAINT_DEFINITION = "order order1 Mandatory: primitive1 clone1"
    end
  end
end
