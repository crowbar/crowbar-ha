require_relative "../../libraries/pacemaker/resource/clone"

class Chef
  module RSpec
    module Pacemaker
      module Config
        CLONE_RESOURCE = ::Pacemaker::Resource::Clone.new("clone1")
        CLONE_RESOURCE.rsc = "primitive1"
        CLONE_RESOURCE.meta = [
          ["globally-unique", "true"],
          ["clone-max",       "2"],
          ["clone-node-max",  "2"]
        ]
        CLONE_RESOURCE_DEFINITION = <<'EOF'.chomp
clone clone1 primitive1 \
         meta clone-max="2" clone-node-max="2" globally-unique="true"
EOF
      end
    end
  end
end
