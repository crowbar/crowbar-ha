def upgrade(ta, td, a, d)
  a.delete("setup_hb_gui")
  return a, d
end

def downgrade(ta, td, a, d)
  a["setup_hb_gui"] = ta["setup_hb_gui"]
  return a, d
end
