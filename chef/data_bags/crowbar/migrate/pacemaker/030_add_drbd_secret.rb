def upgrade(ta, td, a, d)
  # We use a class variable to set the same password in the proposal and in the
  # role
  unless defined?(@@drbd_shared_secret)
    service = ServiceObject.new "fake-logger"
    @@drbd_shared_secret = service.random_password
  end
  a["drbd"]["shared_secret"] = @@drbd_shared_secret

  return a, d
end

def downgrade(ta, td, a, d)
  a["drbd"].delete("shared_secret")
  return a, d
end
