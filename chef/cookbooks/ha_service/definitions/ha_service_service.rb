define :ha_service_service do

  ha_service_name="ha_service-#{params[:name]}"

  service ha_service_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "restart #{ha_service_name}"
      stop_command "stop #{ha_service_name}"
      start_command "start #{ha_service_name}"
      status_command "status #{ha_service_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    supports :status => true, :restart => true
    action [:enable, :start]
    subscribes :restart, resources(:template => node[:ha_service][:config_file])
  end

end
