require_relative "clone"

class Pacemaker::Resource::MasterSlave < Pacemaker::Resource::Clone
  register_type :ms

  #include Pacemaker::Mixins::Resource::Meta

  attr_accessor :rsc
end
