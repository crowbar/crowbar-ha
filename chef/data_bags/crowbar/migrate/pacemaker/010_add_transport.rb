def upgrade ta, td, a, d
  a["corosync"]["transport"] = ta["corosync"]["transport"]
  return a, d
end

def downgrade ta, td, a, d
  a["corosync"].delete("transport")
  return a, d
end
