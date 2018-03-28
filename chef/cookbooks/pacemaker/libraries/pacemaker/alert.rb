require "shellwords"

require_relative "cib_object"
require_relative "mixins/resource_meta"

module Pacemaker
  class Alert < Pacemaker::CIBObject
    register_type :alert

    include Pacemaker::Mixins::Resource::Meta

    attr_accessor :handler, :receiver

    def self.attrs_to_copy_from_chef
      %w(handler receiver meta)
    end

    def parse_definition
      unless @definition =~ /\A#{self.class.object_type} (\S+) "(\S+)"/
        raise Pacemaker::CIBObject::DefinitionParseError, \
              "Couldn't parse definition '#{@definition}'"
      end
      self.name = Regexp.last_match(1)
      self.handler = Regexp.last_match(2)
      self.meta = self.class.extract_hash(@definition, "meta")
      self.receiver = self.class.find_all_to_extract(@definition, "to")[0]

      attrs_authoritative
    end

    def definition_from_attributes
      str = "#{self.class.object_type} #{name} \"#{handler}\""
      str << continuation_line(meta_string) unless meta.nil? || meta.empty?
      str << continuation_line("to #{receiver}") unless receiver.nil? || receiver.empty?
      str
    end

    def self.description
      "alert"
    end
  end
end
