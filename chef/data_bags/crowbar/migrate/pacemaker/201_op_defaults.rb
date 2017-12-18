def upgrade(ta, td, a, d)
  a["op_defaults"] = ta["op_defaults"] unless a.key? "op_defaults"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("op_defaults") unless ta.key? "op_defaults"
  return a, d
end
