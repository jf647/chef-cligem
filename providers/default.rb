require 'pathname'

def whyrun_supported?
    true
end

action :install do
    if @current_resource.exists
        Chef::Log.info "#{@new_resource} already installed - nothing to do."
    else
        converge_by("Install #{@new_resource}") do
            install_gem
        end
    end
    ruby_remove_exec_action
end

action :upgrade do
    if @current_resource.exists
        converge_by("Upgrade #{@new_resource}") do
            upgrade_gem
        end
    else
        Chef::Log.warn "#{@new_resource} not installed - treating upgrade as install"
        converge_by("Install #{@new_resource}") do
            install_gem
        end
    end
    ruby_remove_exec_action
end

def load_current_resource
    init_resource(new_resource)
    @current_resource = Chef::Resource::Cligem.new(new_resource.name)
    init_resource(@current_resource)
end

def init_resource(r)
    r.directory      r.directory || "/opt/#{r.name}"
    r.gem_bins       r.gem_bins || [ r.name ]
    if ! r.rubygems_source.nil?
        r.rubygems_source r.rubygems_source
    elsif node.key?(:cligem) && ! node[:cligem][:rubygems_source].nil?
        r.rubygems_source node[:cligem][:rubygems_source]
    else
        r.rubygems_source 'https://rubygems.org'
    end
    if r.gems.nil?
        r.gems [ { :name => r.name, :version => r.version, :spec => r.gemspec } ]
    end
    r.gemfile_lock = Pathname.new(r.directory) + 'Gemfile.lock'
    if r.gemfile_lock.exist?
        r.exists = true
    end
end

def install_gem
    directory new_resource.directory do
        owner new_resource.owner
        group new_resource.group
        mode new_resource.directory_mode
    end
    bundle_config
    gemfile_template
    bash "bundle install #{new_resource.name}" do
        cwd new_resource.directory
        user new_resource.owner
        group new_resource.group
        code <<-eos
            source /etc/profile.d/rbenv.sh
            bundle install
        eos
        if new_resource.exec_only_gem_bins
            notifies :run, "ruby_block[remove exec from #{current_resource.name} dependency gem bins]", :delayed
        end
    end
    if new_resource.add_profile_d
        template "/etc/profile.d/#{new_resource.name}.sh" do
            cookbook 'cligem'
            owner "root"
            group "root"
            source "profile.d.sh.erb"
            mode 0755
            variables( { :directory => new_resource.directory } )
        end
    end
    node.set[:cligem][:install_dir][new_resource.name] = new_resource.directory
end

def upgrade_gem
    bundle_config
    gemfile_template
    bash "bundle update #{new_resource.name}" do
        cwd new_resource.directory
        user new_resource.owner
        group new_resource.group
        code <<-eos
            source /etc/profile.d/rbenv.sh
            bundle update
        eos
        if new_resource.exec_only_gem_bins
            notifies :run, "ruby_block[remove exec from #{current_resource.name} dependency gem bins]", :delayed
        end
    end
end

def gemfile_template
    template "#{new_resource.directory}/Gemfile" do
        cookbook 'cligem'
        owner new_resource.owner
        group new_resource.group
        mode 0644
        source "Gemfile.erb"
        variables( {
            :rubygems_source => new_resource.rubygems_source,
            :gems => new_resource.gems,
        } )
    end
end

def ruby_remove_exec_action
    ruby_block "remove exec from #{current_resource.name} dependency gem bins" do
        block do
            require 'pathname'
            require 'fileutils'
            bindir = Pathname.new("#{new_resource.directory}/bin")
            bindir.each_child do |c|
                if c.file?
                    if new_resource.gem_bins.include?(c.basename.to_s)
                        Chef::Log.debug "setting #{c.to_s} executable"
                        FileUtils.chmod new_resource.exec_mode, c.to_s
                    else
                        Chef::Log.debug "setting #{c.to_s} non-executable"
                        FileUtils.chmod new_resource.nonexec_mode, c.to_s
                    end
                end
            end
        end
    end
end

def bundle_config
    directory "#{new_resource.directory}/.bundle" do
        owner new_resource.owner
        group new_resource.group
        mode 0755
    end
    template "#{new_resource.directory}/.bundle/config" do
        cookbook 'cligem'
        owner new_resource.owner
        group new_resource.group
        mode 0644
        source "bundle_config.erb"
        variables( { :rbenv_ruby => "#{node['rbenv']['root_path']}/shims/ruby" } )
    end
end
