require_relative "../../libraries/pacemaker/resource/group"

class Chef
  module RSpec
    module Pacemaker
      module Config
        RESOURCE_GROUP =
          ::Pacemaker::Resource::Group.new("group1")
        RESOURCE_GROUP.members = ["resource1", "resource2"]
        RESOURCE_GROUP.meta = [
          ["is-managed", "true"]
        ]
        RESOURCE_GROUP_DEFINITION = <<'EOF'.chomp
group group1 resource1 resource2 \
         meta is-managed="true"
EOF
      end
    end
  end
end
