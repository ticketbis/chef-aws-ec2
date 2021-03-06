actions :create, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :vpc, kind_of: String, required: true
attribute :default_route, kind_of: String
attribute :routes, kind_of: Hash, default: {}
attribute :region, kind_of: String
attribute :access_key_id, kind_of: String
attribute :secret_access_key, kind_of: String

attr_accessor :client, :vpc_o, :route_table, :routes_o

def exists?
  not route_table.nil?
end

def id
  route_table.id unless route_table.nil?
end

