return if node[:smbmount].nil? or node[:smbmount][:enabled].nil? or not node[:smbmount][:enabled]

package "cifs-utils"

smb = node[:smbmount]
sa = smb[:sa]
key = smb[:key]

credfile = "/etc/smbcredentials/#{sa}.cred"

directory File.dirname(credfile) do
	owner "root"
	group "root"
	mode "0700"
	recursive true
end

file credfile do
	mode "0400"
	owner "root"
	group "root"
	content "username=#{sa}\npassword=#{key}\n"
end

mp = smb[:mountpoint]

directory mp do
	owner "root"
	group "root"
	mode "0755"
	recursive true
end

options = "nofail,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30"
options = smb[:options] unless smb[:options].nil? or smb[:options].empty?

options = "#{options},credentials=#{credfile}"

fs = smb[:fileshare]

source = "//#{sa}.file.core.windows.net/#{fs}"

Chef::Log.debug("Enable SMB mount #{source} at #{mp}")

mount mp do
	enabled true
	device source
	fstype "cifs"
	options options
end
