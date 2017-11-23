require "shellwords"

require_relative "../resource"
require_relative "../mixins/resource_meta"

class Pacemaker::Resource::Primitive < Pacemaker::Resource
  register_type :primitive

  include Pacemaker::Mixins::Resource::Meta

  attr_accessor :agent, :params, :op

  def initialize(*args)
    super(*args)

    @agent = nil
  end

  def self.attrs_to_copy_from_chef
    %w(agent params meta op)
  end

  def parse_definition
    unless @definition =~ /\A#{self.class.object_type} (\S+) (\S+)/
      raise Pacemaker::CIBObject::DefinitionParseError, \
            "Couldn't parse definition '#{@definition}'"
    end
    self.name  = $1
    self.agent = $2

    %w(params meta).each do |data_type|
      hash = self.class.extract_hash(@definition, data_type)
      writer = (data_type + "=").to_sym
      send(writer, hash)
    end

    self.op = {}
    %w(start stop monitor promote demote).each do |op|
      h = self.class.extract_hash(@definition, "op #{op}")
      self.op[op] = h unless h.empty?
    end

    attrs_authoritative
  end

  def params_string
    self.class.params_string(params)
  end

  def op_string
    self.class.op_string(op)
  end

  def definition_from_attributes
    str = "#{self.class.object_type} #{name} #{agent}"
    %w(params meta op).each do |data_type|
      unless send(data_type).empty?
        data_string = send("#{data_type}_string")
        str << continuation_line(data_string)
      end
    end
    str
  end

  def self.params_string(params)
    return "" if !params || params.empty?
    "params " +
    params.sort.map do |key, value|
      safe = value.is_a?(String) ? value.gsub('"', '\\"') : value.to_s
      %'#{key}="#{safe}"'
    end.join(" ")
  end

  def self.op_string(ops)
    return "" if !ops || ops.empty?
    ops.sort.map do |op, attrs|
      if attrs.nil? || attrs.empty?
        nil
      else
        # crm seems to append interval=0 when there are attributes, but no
        # interval defined, so let's copy that to avoid creating a diff in the
        # definition
        unless attrs.key? "interval"
          attrs = attrs.clone
          attrs["interval"] = "0"
        end
        "op #{op} " + \
          attrs.sort.map do |key, value|
            # Shouldn't be necessary to escape " here since we don't
            # expect any arbitrary string values, but better to be safe.
            safe = value.is_a?(String) ? value.gsub('"', '\\"') : value.to_s
            %'#{key}="#{safe}"'
          end.join(" ")
      end
    end.compact.join(" ")
  end
end
