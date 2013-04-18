# values should be 'yes' or 'no'.
default['corosync']['enable_openais_service'] = 'yes' 

# Cluster nodes: this can be overriden by the environment attribute. 
default['corosync']['cluster']['nodes'] = ["node1", "node2"]



