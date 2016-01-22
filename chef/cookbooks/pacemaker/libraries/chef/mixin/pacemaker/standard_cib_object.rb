require_relative "../../../pacemaker/cib_object"

# Common code used by Pacemaker LWRP providers

class Chef
  module Mixin::Pacemaker
    module StandardCIBObject
      def standard_create_action
        name = new_resource.name

        if @current_resource_definition.nil?
          create_resource(name)
        else
          maybe_modify_resource(name)
        end
      end

      def standard_update_action
        unless @current_resource_definition.nil?
          maybe_modify_resource(new_resource.name)
        end
      end

      # Load the current definition of the object from the CIB, parse
      # it, and return it.  This is just a helper method for
      # #standard_load_current_resource.
      def load_current_cib_object(name)
        cib_object = ::Pacemaker::CIBObject.from_name(name)
        unless cib_object
          ::Chef::Log.debug "CIB object definition nil or empty"
          return nil
        end

        unless cib_object.is_a? cib_object_class
          expected_type = cib_object_class.description
          ::Chef::Log.warn "CIB object '#{name}' was a #{cib_object.type} not a #{expected_type}"
          return nil
        end

        ::Chef::Log.debug "CIB object '#{name}' currently defined as:\n#{cib_object.definition}"
        @current_resource_definition = cib_object.definition

        cib_object
      end

      # Instantiate @current_resource as a new Chef::Resource::*
      # object and read details about the existing CIB object (if any)
      # via "crm configure show" into it, so that we can compare it
      # against the resource requested by the recipe, and create /
      # delete / modify as necessary.
      #
      # http://docs.opscode.com/lwrp_custom_provider_ruby.html#load-current-resource
      def standard_load_current_resource
        name = @new_resource.name
        @current_cib_object = load_current_cib_object(name)
        return if @current_cib_object.nil?

        @current_resource = @new_resource.class.new(name)
        @current_cib_object.copy_attrs_to_chef_resource(@current_resource,
                                                        *resource_attrs)
      end

      # In Pacemaker, target-role defaults to 'Started', but we want
      # to allow consumers of the LWRPs the choice whether their
      # newly created resource gets started or not, and we also want
      # to adhere to the Principle of Least Surprise.  Therefore we
      # stick to the intuitive semantics that
      #
      #   action :create
      #
      # creates the resource with target-role="Stopped" in order to
      # prevent it from starting immediately, whereas
      #
      #   action [:create, :start]
      #
      # creates the resource and then starts it.
      #
      # Consequently we deprecate setting target-role values directly
      # via the meta attribute.
      def deprecate_target_role
        if new_resource.respond_to? :meta
          meta = new_resource.meta
          if ! ENV["RSPEC_RUNNING"] && meta && meta["target-role"]
            ::Chef::Log.warn "#{new_resource} used deprecated target-role " +
              "#{meta['target-role']}; use action :start / :stop instead"
          end
        end
      end

      def standard_create_resource
        deprecate_target_role

        cib_object = cib_object_class.from_chef_resource(new_resource)

        # We don't want resources to automatically start on creation;
        # only when the :create action is invoked.  However Pacemaker
        # defaults target-role to "Started", so we need to override it.
        if cib_object.respond_to? :meta # might be a constraint
          cib_object.meta["target-role"] = "Stopped"
        end

        cmd = cib_object.configure_command

        ::Chef::Log.info "Creating new #{cib_object}"

        execute cmd do
          action :nothing
        end.run_action(:run)

        created_cib_object = ::Pacemaker::CIBObject.from_name(new_resource.name)

        raise "Failed to create #{cib_object}" if created_cib_object.nil?
        unless created_cib_object.exists?
          # This case seems pretty unlikely
          raise "Definition missing for #{created_cib_object} after creation"
        end

        new_resource.updated_by_last_action(true)
        ::Chef::Log.info "Successfully configured #{created_cib_object}"
      end

      def standard_maybe_modify_resource(name)
        deprecate_target_role

        Chef::Log.info "Checking existing #{@current_cib_object} for modifications"

        desired = cib_object_class.from_chef_resource(new_resource)

        if new_resource.respond_to? :meta
          # Ignore target-role for runnable resources which have meta
          # attributes (this excludes constraints).
          #
          # See comment in primitive provider as to why we do this.
          new_resource.meta.delete("target-role")
          desired.meta.delete("target-role")
        end

        if desired.definition != @current_cib_object.definition
          Chef::Log.debug \
            "changed from [#{@current_cib_object.definition}] " \
            "to [#{desired.definition}]"
          cmd = desired.reconfigure_command
          execute cmd do
            action :nothing
          end.run_action(:run)
          new_resource.updated_by_last_action(true)
        end
      end

      def standard_delete_resource
        execute @current_cib_object.delete_command do
          action :nothing
        end.run_action(:run)
        new_resource.updated_by_last_action(true)
        Chef::Log.info "Deleted #{@current_cib_object}'."
      end
    end
  end
end
