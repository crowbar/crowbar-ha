def upgrade(ta, td, a, d)
  founder_name = d["elements"]["pacemaker-cluster-member"].first
  d["elements"]["pacemaker-cluster-member"].each do |n|
    begin
      node = Chef::Node.load(name)
      next unless node.key?("pacemaker")
      founder_name = name if node["pacemaker"]["founder"] == name
      node["pacemaker"].delete("founder")
      node.save
    rescue Net::HTTPServerException => e
      raise e if e.response.code != "404"
    end
  end
  # are we a role? If yes, save the founder info there
  #  - crowbar-committing is always true for roles, and generally false for
  #    proposals (except when applying)
  #  - the pacemaker barclamp adds an required_post_chef_calls attribute to the
  #    deployment part of the role
  if d["crowbar-committing"] && d.key?("required_post_chef_calls")
    a["founder"] = founder_name
  end
  return a, d
end

def downgrade(ta, td, a, d)
  founder_name = d["elements"]["pacemaker-cluster-member"].first
  d["elements"]["pacemaker-cluster-member"].each do |n|
    begin
      node = Chef::Node.load(name)
      node.set["pacemaker"]["founder"] = (name == founder_name)
      node.save
    rescue Net::HTTPServerException => e
      raise e if e.response.code != "404"
    end
  end
  a.delete("founder")
  return a, d
end
