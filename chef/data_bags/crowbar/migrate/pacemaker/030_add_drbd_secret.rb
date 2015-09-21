def upgrade(ta, td, a, d)
  a["drbd"]["shared_secret"] = ta["drbd"]["shared_secret"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["drbd"].delete("shared_secret")
  return a, d
end
