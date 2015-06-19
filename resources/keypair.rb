actions :create, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :publickey, kind_of: String, required: true
attribute :region, kind_of: String, required: true
attribute :access_key_id, kind_of: String, required: true
attribute :secret_access_key, kind_of: String, required: true

attr_accessor :client, :keypair

def exist?
  not keypair.nil?
end

def id
  keypair.id unless keypair.nil?
end
