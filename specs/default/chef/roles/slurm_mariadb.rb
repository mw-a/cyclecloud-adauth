name "slurm_mariadb"
description "Install mariadb for slurm accounting"
run_list("recipe[ad::slurm_mariadb]")
