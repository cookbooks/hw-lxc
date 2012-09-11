require 'securerandom'

def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  new_resource.utsname new_resource.name unless new_resource.utsname
  new_resource.rootfs "/var/lib/lxc/#{new_resource.utsname}/rootfs" unless new_resource.rootfs
  new_resource.mount "/var/lib/lxc/#{new_resource.utsname}/fstab" unless new_resource.mount
  config = LxcFileConfig.new(new_resource._lxc.container_config)
  if((new_resource.network.nil? || new_resource.network.empty?))
    if(config.network.empty?)
      new_resource.network(
        :type => :veth,
        :link => node[:lxc][:bridge],
        :flags => :up,
        :hwaddr => "00:16:3e#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}"
      )
    else
      new_resource.network(config.network.first)
    end
  else
    [new_resource.network].flatten.each_with_index do |net_hash, idx|
      if(config.network[idx].nil? || config.network[idx][:hwaddr].nil?)
        net_hash[:hwaddr] ||= "00:16:3e#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}"
      end
    end
  end
end

action :create do
  ruby_block "lxc config_updater[#{new_resource.utsname}]" do
    block do
      new_resource.updated_by_last_action(true)
    end
    action :nothing
  end

  directory new_resource._lxc.container_path do
    action :create
  end

  file "lxc update_config[#{new_resource.utsname}]" do
    path new_resource._lxc.container_config
    content LxcFileConfig.generate_config(new_resource)
    mode 0644
    notifies :create, resources(:ruby_block => "lxc config_updater[#{new_resource.utsname}]"), :immediately
  end
end
