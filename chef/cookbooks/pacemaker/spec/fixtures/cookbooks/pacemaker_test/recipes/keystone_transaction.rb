include_recipe "pacemaker_test::keystone_primitive"
include_recipe "pacemaker_test::keystone_clone"
include_recipe "pacemaker_test::keystone_location"

pacemaker_transaction "keystone clone" do
  cib_objects [
    "pacemaker_primitive[keystone]",
    "pacemaker_clone[cl-keystone]",
    "pacemaker_location[l-keystone]",
  ]
  action :commit_new
end
