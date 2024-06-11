return if node[:ondemand].nil? or node[:ondemand][:portal].nil?

servername = node[:ondemand][:portal][:serverName]

return if servername.nil? or servername.empty?

hn, *dummy = servername.split(/\./)
# from https://github.com/chef-boneyard/chef_hostname/blob/c9838b625916d5e2ec1459b0eddc6c6405d87f37/resources/hostname.rb#L93C1-L96C12
execute "hostnamectl set-hostname #{hn}" do
	not_if { shell_out!("hostnamectl status", { :returns => [0, 1] }).stdout =~ /Static hostname:\s+#{hn}/ }
end
