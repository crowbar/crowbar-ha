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

    # This method finds all the entries matching a data_type. This can deal
    # with a string like:
    #         op monitor interval="10" timeout=30s \
    #         op monitor interval="10" timeout=30s role=Master \
    #         op monitor interval="10" role=Slave op monitor role=Foo \
    # That is: entries on multiple lines, and even intries within the same line.
    def self.find_all_to_extract(string, data_type)
      results = string.scan(/\s+#{data_type} (.*?)\s*\\?$/).map { |x| x[0] }
      unless results.empty?
        # Careful here: we make sure we keep the results in the right order,
        # even when going recursive
        recursive_results = results.map { |x| [x, find_all_to_extract(x, data_type)] }
        results = recursive_results.flatten
      end
      results
    end

    # This method extracts a Hash from one of the params / meta / op matching
    # the requested data_type.
    def self.extract_hash_from_one(string, data_type)
      h = {}
      # Shellwords.split behaves just like word splitting in Bourne
      # shell, eating backslashes, so we have to escape them.  This
      # should ensure the keys and values in the string representation
      # of the hash are preserved through the splitting.  The only
      # except is escaped double quotes (\"), for which we want the
      # backslash to be eaten, because complex crm attribute values
      # are represented inside double quotes, e.g. foo="bar\"baz"
      hash_string = string.gsub(/\\([^"])/) { |m| '\\' + m }

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

    # This method extracts the list of Hash from the params / meta / op
    # matching the requested data_type. This should never return more than one
    # result, unless we're looking for an op.
    def self.extract_hash(obj_definition, data_type)
      results = find_all_to_extract(obj_definition, data_type).map do |string|
        extract_hash_from_one(string, data_type)
      end

      if results.empty?
        {}
      elsif results.length == 1
        results[0]
      else
        if data_type !~ /^op (.*)$/
          raise "Many results when extracting hash for #{data_type} from "\
              "#{obj_definition} while this is not an op!"
        end
        results
      end
    end
  end
end
