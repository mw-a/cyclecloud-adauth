name "slurm_scheduler_role_ad"
description "Slurm Scheduler Role AD"
run_list("role[slurm_scheduler_role]",
  "recipe[ad::permanent_mounts]")
