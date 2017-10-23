def upgrade(ta, td, a, d)
  # stay compatible with previous behavior
  a["clone_stateless_services"] = true unless a.key?("clone_stateless_services")
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("clone_stateless_services") unless ta.key?("clone_stateless_services")
  return a, d
end
