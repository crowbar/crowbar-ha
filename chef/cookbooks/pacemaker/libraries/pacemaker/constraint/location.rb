require_relative "../constraint"

class Pacemaker::Constraint::Location < Pacemaker::Constraint
  register_type :location

  attr_accessor :rsc, :score, :lnode

  def self.attrs_to_copy_from_chef
    %w(rsc score lnode)
  end

  def parse_definition
    unless @definition =~ /^#{self.class.object_type} (\S+) (\S.+)/
      raise Pacemaker::CIBObject::DefinitionParseError, \
            "Couldn't parse definition '#{@definition}'"
    end
    self.name = $1
    rest = $2

    if rest =~ /(\S+) (\d+|[-+]?inf): (\S+)\s*$/
      self.rsc = $1
      self.score = $2
      self.lnode = $3
      attrs_authoritative
    end
  end

  def definition_from_attributes
    "#{self.class.object_type} #{name} #{rsc} #{score}: #{lnode}"
  end
end
