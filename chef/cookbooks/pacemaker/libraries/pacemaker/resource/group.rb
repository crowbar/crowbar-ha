require_relative "../resource"
require_relative "../mixins/resource_meta"

class Pacemaker::Resource::Group < Pacemaker::Resource
  register_type :group

  include Pacemaker::Mixins::Resource::Meta

  # FIXME: need to handle params as well as meta

  attr_accessor :members

  def self.attrs_to_copy_from_chef
    %w(members meta)
  end

  def parse_definition
    unless @definition =~ /^#{self.class.object_type} (\S+) (.+?)(\s+\\)?$/
      raise Pacemaker::CIBObject::DefinitionParseError, \
            "Couldn't parse definition '#{@definition}'"
    end
    self.name    = $1
    members = $2.split
    trim_from = members.find_index("meta")
    members = members[0..trim_from-1] if trim_from
    self.members = members
    self.meta    = self.class.extract_hash(@definition, "meta")

    attrs_authoritative
  end

  def definition_from_attributes
    str = "#{self.class.object_type} #{name} " + members.join(" ")
    unless meta.empty?
      str << continuation_line(meta_string)
    end
    str
  end
end
