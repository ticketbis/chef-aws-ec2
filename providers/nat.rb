include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

action :create do
  create_base
end

action :delete do
  create_base :delete
end

private

def create_base action=:create
  if action == :create then action = [:create, :start]
  end
  aws_ec2_instance new_resource.name do
    vpc new_resource.vpc
    image Chef::AwsEc2.get_image(aws_region, 'nat')
    instance_type 't2.micro'
    subnet new_resource.subnet
    key_name new_resource.key_name
    security_groups new_resource.security_groups
    user_data new_resource.user_data
    user_data_allow_stop new_resource.user_data_allow_stop
    monitoring new_resource.monitoring
    disable_api_termination new_resource.disable_api_termination
    instance_initiated_shutdown_behavior new_resource.instance_initiated_shutdown_behavior
    ebs_optimized new_resource.ebs_optimized
    source_dest_check false
    allow_stopping new_resource.allow_stopping
    wait new_resource.wait
    wait_delay new_resource.wait_delay
    wait_attempts new_resource.wait_attempts
    assign_eip true
    private_dns_name new_resource.private_dns_name
    public_dns_name new_resource.public_dns_name
    region new_resource.region
    access_key_id new_resource.access_key_id
    secret_access_key new_resource.secret_access_key
    action action
  end
end
