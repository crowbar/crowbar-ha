require "shellwords"

require_relative "cib_object"

module Pacemaker
  class Alert < Pacemaker::CIBObject
    register_type :alert

    attr_accessor :handler, :receiver

    def self.attrs_to_copy_from_chef
      %w(handler receiver)
    end

    def parse_definition
      unless @definition =~ /\A#{self.class.object_type} (\S+) (\S+)(?:[\\\s]+to (\S+))?/
        raise Pacemaker::CIBObject::DefinitionParseError, \
              "Couldn't parse definition '#{@definition}'"
      end
      self.name = Regexp.last_match(1)
      self.handler = Regexp.last_match(2)
      self.receiver = Regexp.last_match(3)

      attrs_authoritative
    end

    def definition_from_attributes
      str = "#{self.class.object_type} #{name} #{handler}"
      str << continuation_line("to #{receiver}") unless receiver.nil? || receiver.empty?
      str
    end

    def self.description
      "alert"
    end
  end
end
