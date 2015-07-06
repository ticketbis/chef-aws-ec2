actions :create, :start, :stop, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :vpc, kind_of: String, required: true
attribute :image, kind_of: [String, Symbol], required: true
attribute :instance_type, kind_of: String, required: true
attribute :subnet, kind_of: String, required: true
attribute :key_name, kind_of: String
attribute :security_groups, kind_of: [String, Array]
attribute :user_data, kind_of: String
attribute :user_data_allow_stop, equal_to: [true, false], default: false
attribute :monitoring, equal_to: [true,false], default: false
attribute :disable_api_termination, equal_to: [true, false], default: true
attribute :instance_initiated_shutdown_behavior, equal_to: ['stop', 'terminate'], default: 'stop'
attribute :ebs_optimized, equal_to: [true, false], default: false
attribute :source_dest_check, equal_to: [true, false], default: true
attribute :allow_stopping, equal_to: [true, false], default: false
attribute :wait, equal_to: [true, false], default: true
attribute :wait_delay, kind_of: Integer, default: 10
attribute :wait_attempts, kind_of: Integer, default: 30
attribute :assign_eip, equal_to: [true, false], default: false
attribute :private_dns_name, kind_of: [String, Array], default: []
attribute :public_dns_name, kind_of: [String, Array], default: []
attribute :region, kind_of: String
attribute :access_key_id, kind_of: String
attribute :secret_access_key, kind_of: String

attr_accessor :client, :vpc_o, :subnet_o, :instance

def exist?
  not instance.nil?
end

def id
  instance.id unless instance.nil?
end

def after_created
  security_groups([security_groups]) unless @security_groups.nil? or @security_groups.instance_of?Array
  private_dns_name([private_dns_name]) unless @private_dns_name.nil? or @private_dns_name.instance_of?Array
  public_dns_name([public_dns_name]) unless @public_dns_name.nil? or @public_dns_name.instance_of?Array
  fail "TODO: PUBLIC ADDRESSES" unless @public_dns_name.nil?
end
