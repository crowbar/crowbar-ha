require_relative "../../libraries/pacemaker/resource/ms"

class Chef
  module RSpec
    module Pacemaker
      module Config
        MS_RESOURCE = ::Pacemaker::Resource::MasterSlave.new("ms1")
        MS_RESOURCE.rsc = "primitive1"
        MS_RESOURCE.meta = [
          ["globally-unique", "true"],
          ["clone-max",       "2"],
          ["clone-node-max",  "2"],
          ["master-max",      "1"],
          ["master-node-max", "1"]
        ]
        MS_RESOURCE.attrs_authoritative
        MS_RESOURCE_DEFINITION = <<'EOF'.chomp
ms ms1 primitive1 \
         meta clone-max="2" clone-node-max="2" globally-unique="true" master-max="1" master-node-max="1"
EOF
      end
    end
  end
end
