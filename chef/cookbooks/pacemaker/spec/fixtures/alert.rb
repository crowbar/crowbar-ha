require_relative "../../libraries/pacemaker/alert"

class Chef
  module RSpec
    module Pacemaker
      module Config
        ALERT = ::Pacemaker::Alert.new("alert1")
        ALERT.handler = "handler.sh"
        ALERT.attrs_authoritative
        ALERT_DEFINITION = "alert alert1 handler.sh".freeze

        ALERT_WITH_TO = ::Pacemaker::Alert.new("alert2")
        ALERT_WITH_TO.handler = "handler2.sh"
        ALERT_WITH_TO.receiver = "receiver-id"
        ALERT_WITH_TO.attrs_authoritative
        ALERT_DEFINITION_WITH_TO = <<'PCMK'.chomp
alert alert2 handler2.sh \
         to receiver-id
PCMK
      end
    end
  end
end
