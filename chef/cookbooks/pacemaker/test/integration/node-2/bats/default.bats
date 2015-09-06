#!/usr/bin/env bats

@test "Check that pacemaker package is installed" {
    run rpm -q pacemaker
    [[ ${status} == 0 ]]
}

@test "Check that corosync package is installed" {
    run rpm -q corosync
    [[ ${status} == 0 ]]
}

@test "Check that pacemaker daemon is running" {
    run pgrep pacemakerd
    [[ ${status} == 0 ]]
}

@test "Check that corosync daemon is running" {
    run pgrep corosync
    [[ ${status} == 0 ]]
}

@test "Check that necessary resource primitives are setup" {
    crm configure show | grep -e "primitive cluster_vip" -e "primitive haproxy" -q
    ret_code=$?

    [[ ${ret_code} == 0 ]]
}

@test "Check that both the nodes are online" {
    crm_mon -1 | grep -E 'Online.*node-1.*node-2' -q
    ret_code=$?

    [[ ${ret_code} == 0 ]]
}

@test "Check that both the resources are running on the same node" {
    num_resources_running=$(crm_mon -1 | grep -E 'cluster_vip.*Started|haproxy.*Started' | wc -l)
    [[ ${num_resources_running} == "2" ]]

    num_nodes=$(crm_mon -1 | grep -E 'cluster_vip.*Started|haproxy.*Started' | awk '{print $4}' | sort | uniq | wc -l)
    [[ ${num_nodes} == 1 ]]
}
