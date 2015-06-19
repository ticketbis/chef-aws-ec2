actions :create, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :vpc, kind_of: String, required: true
attribute :cidr_block, kind_of: String, required: true
attribute :availability_zone, kind_of: String, default: 'a'
attribute :route_table, kind_of: String
attribute :public_ip, kind_of: [TrueClass, FalseClass], default: false
attribute :region, kind_of: String
attribute :access_key_id, kind_of: String
attribute :secret_access_key, kind_of: String

attr_accessor :client, :vpc_o, :route_table_o, :subnet

def exists?
  not subnet.nil?
end

def id
  subnet.id unless subnet.nil?
end
