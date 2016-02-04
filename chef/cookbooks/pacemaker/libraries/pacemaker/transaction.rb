require "chef/mixin/shell_out"

require_relative "cib_object"

module Pacemaker
  class Transaction
    attr_reader :name, :cib_objects

    def initialize(options = {})
      @name = options.fetch(:name, "")
      @cib_objects = options.fetch(:cib_objects, [])
    end

    def definition
      cib_objects.map { |obj| obj.definition + "\n" }.join ""
    end
  end
end
