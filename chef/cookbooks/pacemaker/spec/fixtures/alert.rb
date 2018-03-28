require_relative "../../libraries/pacemaker/alert"

class Chef
  module RSpec
    module Pacemaker
      module Config
        ALERT = ::Pacemaker::Alert.new("alert1")
        ALERT.handler = "handler.sh"
        ALERT.meta = {}
        ALERT.attrs_authoritative
        ALERT_DEFINITION = "alert alert1 \"handler.sh\"".freeze

        ALERT_WITH_TO = ::Pacemaker::Alert.new("alert2")
        ALERT_WITH_TO.handler = "handler2.sh"
        ALERT_WITH_TO.meta = {}
        ALERT_WITH_TO.receiver = "receiver-id"
        ALERT_WITH_TO.attrs_authoritative
        ALERT_DEFINITION_WITH_TO = <<'PCMK'.chomp
alert alert2 "handler2.sh" \
         to receiver-id
PCMK

        ALERT_WITH_META = ::Pacemaker::Alert.new("alert3")
        ALERT_WITH_META.handler = "handler3.sh"
        ALERT_WITH_META.meta = { "timeout" => "20s" }
        ALERT_WITH_META.receiver = "receiver-id3"
        ALERT_WITH_META.attrs_authoritative
        ALERT_DEFINITION_WITH_META = <<'PCMK'.chomp
alert alert3 "handler3.sh" \
         meta timeout="20s" \
         to receiver-id3
PCMK
      end
    end
  end
end
