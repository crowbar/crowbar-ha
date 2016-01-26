require_relative "../../libraries/pacemaker/resource/clone"

class Chef
  module RSpec
    module Pacemaker
      module Config
        KEYSTONE_CLONE_NAME = "cl-keystone"
        KEYSTONE_CLONE =
          ::Pacemaker::Resource::Clone.new(KEYSTONE_CLONE_NAME)
        KEYSTONE_CLONE.rsc = "keystone"
        KEYSTONE_CLONE.meta = [
          ["globally-unique", "true"],
          ["clone-max",       "2"],
          ["clone-node-max",  "1"]
        ]
        KEYSTONE_CLONE.attrs_authoritative
        KEYSTONE_CLONE_DEFINITION = <<'EOF'.chomp
clone cl-keystone keystone \
         meta clone-max="2" clone-node-max="1" globally-unique="true"
EOF
      end
    end
  end
end
