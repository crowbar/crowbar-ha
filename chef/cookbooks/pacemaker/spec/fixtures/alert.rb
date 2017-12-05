require_relative "../../libraries/pacemaker/alert"

class Chef
  module RSpec
    module Pacemaker
      module Config
        ALERT = ::Pacemaker::Alert.new("alert1")
        ALERT.handler = "handler.sh"
        ALERT.receiver = "receiver-id"
        ALERT.attrs_authoritative
        ALERT_DEFINITION = <<'PCMK'.chomp
alert alert1 handler.sh \
         to receiver-id
PCMK
      end
    end
  end
end
