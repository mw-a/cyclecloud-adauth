name "ood_server_hostname"
description "Set OOD server hostname"
# get it to run before cyclecloud
run_list("recipe[ad::ood_server_hostname]")
