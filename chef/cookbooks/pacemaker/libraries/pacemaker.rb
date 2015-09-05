
require 'chef/recipe'
require 'chef/resource'
require 'chef/provider'

class Chef
  module Pacemaker
    require_relative 'cib_object'
    require_relative 'mixins_resource_meta'
    require_relative 'standard_cib_object'
    require_relative 'stonith'

    # Resources
    require_relative 'resource'
    require_relative 'resource_clone'
    require_relative 'resource_group'
    require_relative 'resource_ms'
    require_relative 'resource_primitive'
    require_relative 'runnable_resource'

    # Constraints
    require_relative 'constraint'
    require_relative 'constraint_colocation'
    require_relative 'constraint_location'
    require_relative 'constraint_order'
  end
end
