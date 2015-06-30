actions :create, :start, :stop, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :vpc, kind_of: String, required: true
attribute :subnet, kind_of: String, required: true
attribute :key_name, kind_of: String
attribute :security_groups, kind_of: [String, Array]
attribute :user_data, kind_of: String
attribute :user_data_allow_stop, equal_to: [true, false], default: false
attribute :monitoring, equal_to: [true,false], default: false
attribute :disable_api_termination, equal_to: [true, false], default: true
attribute :instance_initiated_shutdown_behavior, equal_to: ['stop', 'terminate'], default: 'stop'
attribute :ebs_optimized, equal_to: [true, false], default: false
attribute :allow_stopping, equal_to: [true, false], default: false
attribute :wait, equal_to: [true, false], default: true
attribute :wait_delay, kind_of: Integer, default: 10
attribute :wait_attempts, kind_of: Integer, default: 30
attribute :region, kind_of: String
attribute :access_key_id, kind_of: String
attribute :secret_access_key, kind_of: String
