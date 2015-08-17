require File.expand_path('../constraint', File.dirname(__FILE__))

class Pacemaker::Constraint::Colocation < Pacemaker::Constraint
  TYPE = 'colocation'
  register_type TYPE

  attr_accessor :score
  attr_reader :resources

  def resources=(val)
    case val
    when Array
      @resources = val.join ' '
    when String
      @resources = val
    else
      raise "Tried to set resources attribute for colocation '#{name}' " +
        "to invalid type #{val.class} (#{val.inspect})"
    end
  end

  def self.attrs_to_copy_from_chef
    %w(score resources)
  end

  def parse_definition
    # FIXME: this is incomplete.  It probably doesn't handle resource
    # sets correctly, and certainly doesn't handle node attributes.
    # See the crm(8) man page for the official BNF grammar.
    unless definition =~ /^#{self.class::TYPE} (\S+) (\d+|[-+]?inf): (.+?)\s*$/
      raise Pacemaker::CIBObject::DefinitionParseError, \
        "Couldn't parse definition '#{definition}'"
    end
    self.name  = $1
    self.score = $2
    self.resources = $3
  end

  def definition_string
    "#{self.class::TYPE} #{name} #{score}: #{resources}"
  end

end
