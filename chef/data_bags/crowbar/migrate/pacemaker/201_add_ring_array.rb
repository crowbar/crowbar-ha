def upgrade_to_multi_ring(corosync)
  # skip if already upgraded
  return if corosync["rings"]

  # initialize ring with prior, hard-coded network
  ring = {
    "network" => "admin"
  }

  # move flat list of attributes into first ring
  ring_attributes = [
    "bind_addr",
    "mcast_addr",
    "mcast_port",
    "members"
  ]
  ring_attributes.each do |attr|
    ring[attr] = corosync[attr] if corosync[attr]
    corosync.delete attr
  end

  # save ring
  corosync["rings"] = [ring]
end

def upgrade(ta, td, a, d)
  upgrade_to_multi_ring(a["corosync"])

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
      upgrade_to_multi_ring(role.default_attributes["corosync"])
      role.save
    rescue Net::HTTPServerException => e # role does not exist on the chef server
      raise e if e.response.code != "404"
    end
  end

  return a, d
end

def downgrade_to_single_ring(corosync)
  # skip if already downgraded
  return unless corosync["rings"]

  # move values from first ring to a flat list
  ring_attributes = [
    "bind_addr",
    "mcast_addr",
    "mcast_port",
    "members"
  ]
  if corosync["rings"] && !corosync["rings"].empty?
    # downgrade to a single ring
    ring = corosync["rings"][0]
    ring_attributes.each { |attr| corosync[attr] = ring[attr] if ring[attr] }
  end
  corosync.delete "rings"
end

def downgrade(ta, td, a, d)
  downgrade_to_single_ring(a["corosync"])

  unless d.key?("required_post_chef_calls")
    begin
      role = Chef::Role.load(d["config"]["environment"])
      downgrade_to_single_ring(role.default_attributes["corosync"])
      role.save
    rescue Net::HTTPServerException => e # role does not exist on the chef server
      raise e if e.response.code != "404"
    end
  end

  return a, d
end
