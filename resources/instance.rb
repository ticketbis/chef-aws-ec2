def self.IMAGES(region, name)
  return nil if region.nil? or name.nil?
  case name
  when :nat
    case region
    when 'us-east-1' then 'ami-b0210ed8'
    when 'eu-west-1' then 'ami-ef76e898'
    end
  end
end

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
attribute :monitoring, equal_to: [true,false], default: false
attribute :disable_api_termination, equal_to: [true, false], default: true
attribute :instance_initiated_shutdown_behavior, equal_to: ['stop', 'terminate'], default: 'stop'
attribute :ebs_optimized, equal_to: [true, false], default: false
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
  security_groups([security_groups]) unless security_groups.nil? or security_groups.instance_of?Array
end
