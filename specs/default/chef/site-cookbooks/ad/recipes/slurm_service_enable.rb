if not node[:slurm].nil?
	defer_block 'Delayed enablement of services' do
		service "munge" do
			action :enable
		end

		role = node[:slurm][:role]
		if role == "execute"
			service "slurmd" do
				action :enable
			end
		end

		if role == "scheduler"
			service "slurmdbd" do
				action :enable
			end

			service "slurmctld" do
				action :enable
			end
		end
	end
end
