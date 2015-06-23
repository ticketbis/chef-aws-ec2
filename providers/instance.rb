include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  @current_resource = Chef::Resource::AwsEc2Instance.new @new_resource.name
  current_resource.client = Chef::AwsEc2.get_client aws_credentials, aws_region
  current_resource.instance = Chef::AwsEc2.get_instance current_resource.name, current_resource.client unless current_resource.client.nil?
  puts current_resource.instance
  unless current_resource.instance.nil?
  end
end

action :create do
  i = Chef::Resource::AwsEc2Instance.IMAGES(aws_region, new_resource.image) if new_resource.image.instance_of? Symbol
  i = new_resource.image.to_s if i.nil?
  fail "Invalid image ID '#{i}'" unless /^ami-/ =~ i
  vpc = Chef::AwsEc2.get_vpc new_resource.vpc, current_resource.client
  fail "Unknown VPC '#{new_resource.vpc}'" if vpc.nil?
  subnet = Chef::AwsEc2.get_subnet vpc, new_resource.subnet
  fail "Unknown subnet '#{new_resource.subnet}'" if subnet.nil?
  unless new_resource.security_groups.nil?
    fail "Security groups must be all strings" unless new_resource.security_groups.all?{|x| x.instance_of?String}
    sgs = new_resource.security_groups.map do |sg|
      res = Chef::AwsEc2.get_security_group(vpc, sg)
      fail "Security group '#{sg}' not found" if res.nil?
      res.id
    opts[:security_group_ids] = sgs unless sgs.nil? or sgs.empty?
    end
  end
  converge_by "Creating instance '#{new_resource.name}'" do
    opts = {
      image_id: i,
      min_count: 1, max_count: 1,
      instance_type: new_resource.instance_type,
      subnet_id: subnet.id
    }
    opts[:key_name] = new_resource.key_name unless new_resource.key_name.nil?
    r = current_resource.client.run_instances(opts)
    current_resource.client.create_tags(
      resources: r.instances.map{|i| i.instance_id},
      tags: [{ key: 'Name', value: new_resource.name}]
    )
    load_current_resource
  end unless current_resource.exist?
end

action :delete do
  converge_by "Deleting instance '#{new_resource.name}'" do
    current_resource.instance.terminate
  end if current_resource.exist?
end
