require_relative "../constraint"

class Pacemaker::Constraint::Order < Pacemaker::Constraint
  register_type :order

  attr_accessor :score, :ordering

  def self.attrs_to_copy_from_chef
    %w(score ordering)
  end

  def parse_definition
    # FIXME: add support for symmetrical=<bool>
    # Currently we take the easy way out and don't bother parsing the ordering.
    # See the crm(8) man page for the official BNF grammar.
    # It can be fixed in the same way location has been fixed.
    score_regexp = %r{\d+|[-+]?inf|Mandatory|Optional|Serialize}
    unless @definition =~ /^#{self.class.object_type} (\S+) (#{score_regexp}): (.+?)\s*$/
      raise Pacemaker::CIBObject::DefinitionParseError, \
            "Couldn't parse definition '#{@definition}'"
    end
    self.name  = $1
    self.score = $2
    self.ordering = $3
    attrs_authoritative
  end

  def definition_from_attributes
    "#{self.class.object_type} #{name} #{score}: #{ordering}"
  end
end
