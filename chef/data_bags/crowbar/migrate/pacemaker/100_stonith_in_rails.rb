def upgrade(ta, td, a, d)
  # are we a role? If no, nothing to do.
  #  - crowbar-committing is always true for roles, and generally false for
  #    proposals (except when applying)
  #  - the pacemaker barclamp adds an required_post_chef_calls attribute to the
  #    deployment part of the role
  return [a, d] unless d["crowbar-committing"] && d.key?("required_post_chef_calls")

  members = d["elements"]["pacemaker-cluster-member"] || []
  member_nodes = members.map { |n| NodeObject.find_node_by_name n }
  remotes = d["elements"]["pacemaker-remote"] || []
  remote_nodes = remotes.map { |n| NodeObject.find_node_by_name n }

  service = PacemakerService.new
  service.prepare_stonith_attributes(a, remote_nodes, member_nodes, remotes, members)

  return a, d
end

def downgrade(ta, td, a, d)
  # nothing; it doesn't hurt to keep the changes
  return a, d
end
