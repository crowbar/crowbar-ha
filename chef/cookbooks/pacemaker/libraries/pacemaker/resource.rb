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
  end
end
