
actions :create, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :cidr_block, kind_of: String, required: true
attribute :instance_tenancy , kind_of: String, equal_to: ['default', 'dedicated'], default: 'default'
attribute :enable_dns_support , kind_of: [TrueClass, FalseClass], default: true
attribute :enable_dns_hostnames , kind_of: [TrueClass, FalseClass],  default: false
attribute :internet_gateway , kind_of: [TrueClass, FalseClass],  default: true
attribute :region, kind_of: String
attribute :access_key_id, kind_of: String
attribute :secret_access_key, kind_of: String

attr_accessor :client, :vpc

def after_created
  raise Chef::Exceptions::ValidationFailed.new ':cidr_block required for :create action' if action == :create and not cidr_block
end

def exists?
  not vpc.nil?
end

def has_igw?
  vpc.internet_gateways.count > 0
end

def id
  vpc.id unless vpc.nil?
end
