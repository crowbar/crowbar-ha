def upgrade(ta, td, a, d)
  if a["drbd"]["enabled"]
    a["drbd"]["nodes"] = d["elements"]["pacemaker-cluster-member"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["drbd"].delete("nodes")
  return a, d
end
