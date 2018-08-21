def upgrade(ta, td, a, d)
  unless a["drbd"].key? "allow_larger_cluster"
    a["drbd"]["allow_larger_cluster"] = ta["drbd"]["allow_larger_cluster"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["drbd"].key? "allow_larger_cluster"
    a["drbd"].delete("allow_larger_cluster")
  end
  return a, d
end
