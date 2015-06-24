include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  @current_resource = Chef::Resource::AwsEc2Instance.new @new_resource.name
  current_resource.client = Chef::AwsEc2.get_client aws_credentials, aws_region
  current_resource.vpc_o = Chef::AwsEc2.get_vpc new_resource.vpc, current_resource.client unless current_resource.client.nil?
  fail "Unknown VPC '#{new_resource.vpc}'" if current_resource.vpc_o.nil?
  current_resource.subnet_o = Chef::AwsEc2.get_subnet current_resource.vpc_o, new_resource.subnet
  fail "Unknown subnet '#{new_resource.subnet}'" if current_resource.subnet_o.nil?
  current_resource.instance = Chef::AwsEc2.get_instance current_resource.name, current_resource.subnet_o unless current_resource.subnet_o.nil?
  unless current_resource.instance.nil?
    current_resource.image current_resource.instance.image.id
    current_resource.instance_type current_resource.instance.instance_type
  end
end

action :create do
  i = Chef::Resource::AwsEc2Instance.IMAGES(aws_region, new_resource.image)
  fail "Invalid image ID '#{i}'" unless /^ami-/ =~ i
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
    }
    opts[:key_name] = new_resource.key_name unless new_resource.key_name.nil?
    instances = current_resource.subnet_o.create_instances(opts)
    instances.each {|i| i.create_tags(tags: [{ key: 'Name', value: new_resource.name}])}
    instances.each {|i| i.wait_until_running{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}}
    load_current_resource
  end unless current_resource.exist?
end

action :delete do
  converge_by "Deleting instance '#{new_resource.name}'" do
    current_resource.instance.terminate
    current_resource.instance.wait_until_terminate{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}
  end if current_resource.exist?
end

action :start do
  if current_resource.exist?
    case current_resource.instance.state.name
    when 'stopped'
     converge_by "Starting instance '#{new_resource.name}'" do
        current_resource.instance.start
        current_resource.instance.wait_until_running{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}
      end
    when 'running' then
    else Chef::Log.warn "Instance '#{new_resource.name}' in invalid state: #{current_resource.instance.state.name}"
    end
  else
    Chef::Log.warn "Instance '#{new_resource.name}' does not exist"
  end
end

action :stop do
  if current_resource.exist?
    case current_resource.instance.state.name
    when 'running'
      converge_by "Stopping instance '#{new_resource.name}'" do
        current_resource.instance.stop
        current_resource.instance.wait_until_stopped{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}
      end
    when 'stopped' then
    else Chef::Log.warn "Instance '#{new_resource.name}' in invalid state: #{current_resource.instance.state.name}"
    end
  else
    Chef::Log.warn "Instance '#{new_resource.name}' does not exist"
  end
end
