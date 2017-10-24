def upgrade(ta, td, a, d)
  ring = {
    "network" => "admin"
  }
  if a["corosync"]["bind_addr"]
    ring["bind_addr"] = a["corosync"]["bind_addr"]
    a["corosync"].delete "bind_addr"
  end
  if a["corosync"]["mcast_addr"]
    ring["mcast_addr"] = a["corosync"]["mcast_addr"]
    a["corosync"].delete "mcast_addr"
  end
  if a["corosync"]["mcast_port"]
    ring["mcast_port"] = a["corosync"]["mcast_port"]
    a["corosync"].delete "mcast_port"
  end
  if a["corosync"]["members"]
    ring["members"] = a["corosync"]["members"]
    a["corosync"].delete "members"
  end
  a["corosync"]["rings"] = [ring]

  # Are we a proposal? If yes, then look for the applied role if it exists and modify it
  # (the pacemaker barclamp adds an required_post_chef_calls attribute to the
  # deployment part of the role, so we can use that to know if this is the proposal or not)
  # Note that we don't do this step when migrating the role because this would imply
  # loading/saving the role, while the migration scripts will save the role later on
  # with some data that was already loaded before, therefore outdated, and that
  # would break the migration
  unless d.key?("required_post_chef_calls")
    begin
      role = Chef::Role.load(d["config"]["environment"])
      role[:corosync][:rings] = [ring]
      role.save
    rescue Net::HTTPServerException => e # role does not exist on the chef server
      raise e if e.response.code != "404"
    end
  end

  return a, d
end

def downgrade(ta, td, a, d)
  if a["corosync"]["rings"] && !a["corosync"]["rings"].empty?
    ring = a["corosync"]["rings"][0]
    a["corosync"]["bind_addr"] = ring["bind_addr"] if ring["bind_addr"]
    a["corosync"]["mcast_addr"] = ring["mcast_addr"] if ring["mcast_addr"]
    a["corosync"]["mcast_port"] = ring["mcast_port"] if ring["mcast_port"]
    a["corosync"]["members"] = ring["members"] if ring["members"]
  end
  a["corosync"].delete "rings"
  return a, d
end
