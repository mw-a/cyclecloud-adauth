return if node[:slurm].nil? or node[:slurm][:role].nil? or node[:slurm][:role] != "scheduler"

cookbook_file "/etc/cron.d/update_slurm_resources" do
	source "update_slurm_resources.crond"
	owner "root"
	group "root"
	mode 0644
	action :create
end

cookbook_file "/etc/logrotate.d/update_slurm_resources" do
	source "update_slurm_resources.logrotate"
	owner "root"
	group "root"
	mode 0644
	action :create
end
