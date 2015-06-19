def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  @current_resource = Chef::Resource::AwsEc2Keypair.new @new_resource.name
  current_resource.client = Chef::AwsEc2.get_client new_resource.access_key_id, new_resource.secret_access_key, new_resource.region
  current_resource.keypair = Chef::AwsEc2.get_keypair current_resource.name, current_resource.client unless current_resource.client.nil?
end

action :create do
end

action :delete do
end
