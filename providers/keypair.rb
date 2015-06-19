include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  @current_resource = Chef::Resource::AwsEc2Keypair.new @new_resource.name
  current_resource.client = Chef::AwsEc2.get_client aws_credentials, aws_region
  current_resource.keypair = Chef::AwsEc2.get_keypair current_resource.name, current_resource.client unless current_resource.client.nil?
end

action :create do
  converge_by "Creating keypair '#{new_resource.name}'" do
    current_resource.client.import_key_pair(key_name: new_resource.name, public_key_material: new_resource.publickey)
    load_current_resource
  end unless current_resource.exist?
end

action :delete do
  converge_by "Deleting keypair '#{new_resource.name}'" do
    current_resource.client.delete_key_pair(key_name: new_resource.name)
  end if current_resource.exist?
end
