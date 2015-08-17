def upgrade ta, td, a, d
  a["haproxy"]["admin_name"] = ta["haproxy"]["admin_name"]
  return a, d
end

def downgrade ta, td, a, d
  a["haproxy"].delete("admin_name")
  return a, d
end
