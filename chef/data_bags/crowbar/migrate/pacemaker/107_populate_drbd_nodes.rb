def upgrade(ta, td, a, d)
  if a["drbd"]["enabled"]
    a["drbd"]["nodes"] = d["elements"]["pacemaker-cluster-member"]

    d["elements"]["pacemaker-cluster-member"].each do |name|
      node = Node.find_by_name(name)
      next if node.nil? || !node[:pacemaker][:drbd][:enabled]
      node[:pacemaker][:attributes]["drbd-controller"] = true
      node.save
    end
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a["drbd"].delete("nodes")
  return a, d
end
