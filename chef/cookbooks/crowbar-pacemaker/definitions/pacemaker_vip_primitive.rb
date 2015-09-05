define :pacemaker_vip_primitive, cb_network: nil, hostname: nil, domain: nil, op: nil do
  network = params[:cb_network]
  op_params = params[:op]
  net_db = data_bag_item("crowbar", "#{network}_network")
  raise "#{network}_network data bag missing?!" unless net_db
  fqdn = "#{params[:hostname]}.#{params[:domain]}"
  unless net_db["allocated_by_name"][fqdn]
    raise "Missing allocation for #{fqdn} in #{network} network"
  end
  ip_addr = net_db["allocated_by_name"][fqdn]["address"]

  primitive_name = "vip-#{params[:cb_network]}-#{params[:hostname]}"

  pacemaker_primitive primitive_name do
    agent "ocf:heartbeat:IPaddr2"
    params ({
      "ip" => ip_addr
    })
    op op_params
    action :create
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  # we return the primitive name so that the caller can use it as part of a
  # pacemaker group if desired
  primitive_name
end
