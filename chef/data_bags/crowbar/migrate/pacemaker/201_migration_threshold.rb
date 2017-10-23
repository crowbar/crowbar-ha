def upgrade(ta, td, a, d)
  # stay compatible with previous behavior
  unless a["crm"].key?("migration_threshold")
    a["crm"]["migration_threshold"] = ta["crm"]["migration_threshold"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["crm"].delete("migration_threshold") unless ta["crm"].key?("migration_threshold")
  return a, d
end
