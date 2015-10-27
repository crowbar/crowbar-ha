def upgrade(ta, td, a, d)
  a["stonith"]["sbd"]["watchdog_module"] = ta["stonith"]["sbd"]["watchdog_module"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["stonith"]["sbd"].delete("watchdog_module")
  return a, d
end
