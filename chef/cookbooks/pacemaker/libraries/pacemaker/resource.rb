require "chef/mixin/shell_out"

require_relative "cib_object"

module Pacemaker
  class Resource < Pacemaker::CIBObject
    include Chef::Mixin::ShellOut

    def self.description
      type = to_s.split("::").last.downcase
      "#{type} resource"
    end

    def running?
      cmd = shell_out! "crm", "resource", "status", name
      Chef::Log.info cmd.stdout
      !! cmd.stdout.include?("resource #{name} is running")
    end

    def crm_start_command
      "crm --force --wait resource start '#{name}'"
    end

    def crm_stop_command
      "crm --force --wait resource stop '#{name}'"
    end

    # CIB object definitions look something like:
    #
    # primitive keystone ocf:openstack:keystone \
    #         params os_username="crowbar" os_password="crowbar" os_tenant_name="openstack" \
    #         meta target-role="Started" is-managed="true" \
    #         op monitor interval="10" timeout=30s \
    #         op start interval="10s" timeout="240" \
    #
    # This method extracts a Hash from one of the params / meta / op lines.
    def self.extract_hash(obj_definition, data_type)
      unless obj_definition =~ /\s+#{data_type} (.*?)\s*\\?$/
        return {}
      end

      h = {}
      # Shellwords.split behaves just like word splitting in Bourne
      # shell, eating backslashes, so we have to escape them.  This
      # should ensure the keys and values in the string representation
      # of the hash are preserved through the splitting.  The only
      # except is escaped double quotes (\"), for which we want the
      # backslash to be eaten, because complex crm attribute values
      # are represented inside double quotes, e.g. foo="bar\"baz"
      hash_string = $1.gsub(/\\([^"])/) { |m| '\\' + m }

      Shellwords.split(hash_string).each do |kvpair|
        break if kvpair == "op"
        unless kvpair =~ /^(.+?)=(.*)$/
          raise "Couldn't understand '#{kvpair}' for '#{data_type}' section "\
            "of #{name} resource (definition was [#{obj_definition}])"
        end
        k, v = $1, $2
        h[k] = v.sub(/^"(.*)"$/, "\1")
      end
      h
    end
  end
end
