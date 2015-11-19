require "chef/mixin/shell_out"

require_relative "cib_object"

module Pacemaker
  class Transaction
    include Chef::Mixin::ShellOut

    attr_reader :name, :cib_objects

    def initialize(name:, cib_objects:)
      @name = name
      @cib_objects = cib_objects
    end

    def definition
      cib_objects.map { |obj| obj.definition_string + "\n" }.join ""
    end
  end
end
