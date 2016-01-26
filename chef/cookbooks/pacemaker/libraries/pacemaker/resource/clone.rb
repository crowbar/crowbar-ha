require_relative "../resource"
require_relative "../mixins/resource_meta"

class Pacemaker::Resource::Clone < Pacemaker::Resource
  register_type :clone

  include Pacemaker::Mixins::Resource::Meta

  # FIXME: need to handle params as well as meta

  attr_accessor :rsc

  def self.attrs_to_copy_from_chef
    %w(rsc meta)
  end

  def definition_from_attributes
    str = "#{self.class.object_type} #{name} #{rsc}"
    unless meta.empty?
      str << continuation_line(meta_string)
    end
    str
  end

  def parse_definition
    unless @definition =~ /^#{self.class.object_type} (\S+) (\S+)/
      raise Pacemaker::CIBObject::DefinitionParseError, \
            "Couldn't parse definition '#{@definition}'"
    end
    self.name = $1
    self.rsc  = $2
    self.meta = self.class.extract_hash(@definition, "meta")
    attrs_authoritative
  end
end
