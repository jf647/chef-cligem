actions :install, :upgrade
default_action :install

attribute :name, :kind_of => String, :name_attribute => true
attribute :version, :kind_of => String
attribute :gemspec, :kind_of => String
attribute :cookbook, :kind_of => String, :default => "cli_gem"
attribute :directory, :kind_of => String
attribute :directory_mode, :kind_of => Integer, :default => 0755
attribute :gem_bins, :kind_of => Array
attribute :exec_mode, :kind_of => Integer, :default => 0755
attribute :nonexec_mode, :kind_of => Integer, :default => 0644
attribute :exec_only_gem_bins, :equal_to => [ true, false ], :default => true
attribute :owner, :kind_of => String, :default => "root"
attribute :group, :kind_of => String, :default => "root"
attribute :add_profile_d, :equal_to => [ true, false ], :default => true
attribute :rubygems_source, :kind_of => String, :default => 'https://rubygems.org'

attr_accessor :exists, :gemfile_lock

def initialize(*args)
    super
    @exists = false
end
