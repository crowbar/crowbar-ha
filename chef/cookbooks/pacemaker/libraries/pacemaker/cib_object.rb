require "mixlib/shellout"

module Pacemaker
  class CIBObject
    attr_accessor :name

    @@subclasses = { } unless class_variable_defined?(:@@subclasses)

    class << self
      attr_reader :object_type

      def register_type(type_name)
        @object_type = type_name
        @@subclasses[type_name] = self
      end

      def crm_configure_show(name)
        cmd = Mixlib::ShellOut.new("crm --display=plain configure show #{name}")
        cmd.environment["HOME"] = ENV.fetch("HOME", "/root")
        cmd.run_command
        begin
          cmd.error!

          lines_for_def = []
          cmd.stdout.lines.each do |line|
            if lines_for_def.empty?
              # look for the beginning of the resource definition
              next unless line =~ /\A(\w+)\s#{name}\s/
            else
              # stop parsing if we reach the end of our definition
              break if line !~ /\A\s/
            end
            lines_for_def.push(line)
          end

          if lines_for_def.empty?
            # in case our attempt to only extract the definition we're
            # interested in failed, play it safe and return the output
            ::Chef::Log.warn "Failed to extract definition for #{name} from:\n#{cmd.stdout}"
            cmd.stdout
          else
            lines_for_def.join("")
          end
        rescue
          nil
        end
      end

      def exists?(name)
        crm_configure_show(name) ? true : false
      end

      def definition_type(definition)
        unless definition =~ /\A(\w+)\s/
          raise "Couldn't extract CIB object type from '#{definition}'"
        end
        $1.to_sym
      end

      def from_name(name)
        definition = crm_configure_show(name)
        return nil unless definition and ! definition.empty?
        from_definition(definition)
      end

      # Make sure this works on Ruby 1.8.7 which is missing
      # Object#singleton_class.
      def singleton_class
        class << self; self; end
      end

      def from_definition(definition)
        calling_class = self.singleton_class
        this_class = method(__method__).owner
        if calling_class == this_class
          # Invoked via (this) base class
          obj_type = definition_type(definition)
          subclass = @@subclasses[obj_type]
          unless subclass
            raise "No subclass of #{self.name} was registered with type '#{obj_type}'"
          end
          return subclass.from_definition(definition)
        else
          # Invoked via subclass
          obj = new(name)
          unless name == obj.name
            raise "Name '#{obj.name}' in definition didn't match name '#{name}' used for retrieval"
          end
          obj.definition = definition
          obj
        end
      end

      def from_chef_resource(resource)
        new(resource.name).
          copy_attrs_from_chef_resource(resource, *attrs_to_copy_from_chef)
      end

      def attrs_to_copy_from_chef
        raise NotImplementedError, "#{self.class} didn't implement attrs_to_copy_from_chef"
      end
    end

    def initialize(name)
      @name = name
      @definition = nil
      @authority = nil
    end

    def definition=(new_definition)
      @definition = new_definition
      @authority = :definition
      check_definition_type
      parse_definition
    end

    # subclass#parse_definition should call this when parsing is
    # successful, to indicate that the definition should be calculated
    # from attributes rather than just regurgitating the raw string
    # which was originally provided via #definition=.  Returns self to
    # allow method chaining.
    def attrs_authoritative
      @authority = :attributes
      self
    end

    def definition
      case @authority
      when :attributes
        definition_from_attributes
      when :definition
        @definition
      when nil
        raise "#definition called on #{self} before any " \
              "definition authority was set"
      else
        raise "BUG: unrecognised authority '#{@authority}' for #{self}"
      end
    end

    def copy_attrs_from_chef_resource(resource, *attrs)
      any_attrs_set = false
      attrs.each do |attr|
        if copy_attr_from_chef_resource(resource, attr)
          any_attrs_set = true
        end
      end

      if any_attrs_set
        attrs_authoritative
      else
        copy_attr_from_chef_resource(resource, "definition")
      end

      self
    end

    def copy_attr_from_chef_resource(resource, attr)
      value = resource.send(attr.to_sym)
      writer = (attr + "=").to_sym
      send(writer, value)
      value
    end

    def copy_attrs_to_chef_resource(resource, *attrs)
      attrs.each do |attr|
        value = send(attr.to_sym)
        writer = attr.to_sym
        resource.send(writer, value)
      end
    end

    def check_definition_type
      if @definition and ! @definition.empty? and type != self.class.object_type
        raise CIBObject::TypeMismatch, \
              "Expected #{self.class.object_type} type but loaded definition was type #{type}"
      end
    end

    def parse_definition
      raise NotImplementedError, "#{self.class} must implement #parse_definition"
    end

    # N.B. It is not actually required for a subclass to implement
    # this method unless the subclass calls #attrs_authoritative at
    # some point.
    def definition_from_attributes
      raise NotImplementedError, "#{self.class} must implement #definition_from_attributes"
    end

    def exists?
      !! (definition && ! definition.empty?)
    end

    def type
      self.class.definition_type(definition)
    end

    def to_s
      "%s '%s'" % [self.class.description, name]
    end

    def definition_indent
      " " * 9
    end

    def continuation_line(text)
      " \\\n#{definition_indent}#{text}"
    end

    # Returns a single-quoted shell-escaped version of the definition
    # string, suitable for use in a command like:
    #
    #     echo '...' | crm configure load update -
    #
    # In shell, single-quotes cannot exist inside single-quoted strings,
    # so the string has to be terminated, followed by an escaped single
    # quote, and then started again, e.g.:
    #
    #     $ echo 'foo'\''bar'
    #     foo'bar
    def quoted_definition
      "'%s'" % \
        definition.
          gsub("\\'") { |m| '\\' + m }.
          gsub("'")   { |m| %q['\''] }
    end

    def configure_command
      "echo #{quoted_definition} | crm configure load update -"
    end

    def reconfigure_command
      configure_command
    end

    def delete_command
      "crm configure delete '#{name}'"
    end
  end

  class CIBObject::DefinitionParseError < StandardError
  end

  class CIBObject::TypeMismatch < StandardError
  end
end
