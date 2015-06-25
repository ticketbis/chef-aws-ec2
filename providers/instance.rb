include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  self.current_resource = Chef::Resource.resource_for_node(new_resource.declared_type, node).new @new_resource.name
  current_resource.client = Chef::AwsEc2.get_client aws_credentials, aws_region
  current_resource.vpc_o = Chef::AwsEc2.get_vpc new_resource.vpc, current_resource.client unless current_resource.client.nil?
  fail "Unknown VPC '#{new_resource.vpc}'" if current_resource.vpc_o.nil?
  current_resource.subnet_o = Chef::AwsEc2.get_subnet current_resource.vpc_o, new_resource.subnet
  fail "Unknown subnet '#{new_resource.subnet}'" if current_resource.subnet_o.nil?
  current_resource.instance = Chef::AwsEc2.get_instance current_resource.name, current_resource.subnet_o unless current_resource.subnet_o.nil?
  unless current_resource.instance.nil?
    current_resource.image current_resource.instance.image.id
    current_resource.instance_type current_resource.instance.instance_type
    current_resource.key_name current_resource.instance.key_pair.name unless current_resource.instance.key_pair.nil?
    current_resource.security_groups current_resource.instance.security_groups.map{|sg| sg.group_id}.sort unless current_resource.instance.security_groups.nil?
    t = current_resource.instance.describe_attribute(attribute: 'userData').user_data.value
    current_resource.user_data Base64.decode64(t) unless t.nil?
    current_resource.monitoring(current_resource.instance.monitoring.state == 'enabled')
    current_resource.disable_api_termination current_resource.instance.describe_attribute(attribute: 'disableApiTermination').disable_api_termination.value
    current_resource.instance_initiated_shutdown_behavior current_resource.instance.describe_attribute(attribute: 'instanceInitiatedShutdownBehavior').instance_initiated_shutdown_behavior.value
    current_resource.ebs_optimized current_resource.instance.describe_attribute(attribute: 'ebsOptimized').ebs_optimized.value
    current_resource.source_dest_check current_resource.instance.describe_attribute(attribute: 'sourceDestCheck').source_dest_check.value
  end
end

action :create do
  i = Chef::Resource::AwsEc2Instance.IMAGES(aws_region, new_resource.image)
  fail "Invalid image ID '#{i}'" unless /^ami-/ =~ i
  unless new_resource.security_groups.nil?
    fail "Security groups must be all strings" unless new_resource.security_groups.all?{|x| x.instance_of?String}
    sgs = new_resource.security_groups.map do |sg|
      res = Chef::AwsEc2.get_security_group(current_resource.vpc_o, sg)
      fail "Security group '#{sg}' not found" if res.nil?
      res.id
    end
    sgs.sort!
  end
  converge_by "Creating instance '#{new_resource.name}'" do
    opts = {
      image_id: i,
      min_count: 1, max_count: 1,
      instance_type: new_resource.instance_type,
      monitoring: {enabled: new_resource.monitoring},
      disable_api_termination: new_resource.disable_api_termination,
      instance_initiated_shutdown_behavior: new_resource.instance_initiated_shutdown_behavior,
      ebs_optimized: new_resource.ebs_optimized
    }
    opts[:key_name] = new_resource.key_name unless new_resource.key_name.nil?
    opts[:security_group_ids] = sgs unless sgs.nil? or sgs.empty?
    opts[:user_data] = Base64.encode64(new_resource.user_data) unless new_resource.user_data.nil?
    instances = current_resource.subnet_o.create_instances(opts)
    instances.each {|i| i.create_tags(tags: [{ key: 'Name', value: new_resource.name}])}
    instances.each {|i| i.wait_until_running{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}}
    load_current_resource
  end unless current_resource.exist?
  # Check unchangeable values
  fail "Cannot change image id #{current_resource.image} -> #{i}" unless i == current_resource.image
  fail "Cannot change key pair #{current_resource.key_name} -> #{new_resource.key_name}" unless current_resource.key_name == new_resource.key_name
  unless current_resource.instance_type == new_resource.instance_type and current_resource.user_data == new_resource.user_data and current_resource.ebs_optimized == new_resource.ebs_optimized
    if new_resource.allow_stopping
      converge_by "Stopping instance '#{new_resource.name}'" do
        current_resource.instance.stop
        current_resource.instance.wait_until_stopped{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}
      end
      converge_by "Changing instance type #{current_resource.instance_type} -> #{new_resource.instance_type}" do
        current_resource.instance.modify_attribute(instance_type: {value: new_resource.instance_type})
      end unless current_resource.instance_type == new_resource.instance_type
      converge_by "Changing user data" do
        current_resource.instance.modify_attribute(user_data: {value: new_resource.user_data})
      end unless current_resource.user_data == new_resource.user_data
      converge_by "Changing EBS optimization #{current_resource.ebs_optimized} -> #{new_resource.ebs_optimized}" do
        current_resource.instance.modify_attribute(ebs_optimized: {value: new_resource.ebs_optimized})
      end unless current_resource.ebs_optimized == new_resource.ebs_optimized
      converge_by "Starting instance '#{new_resource.name}'" do
        current_resource.instance.start
        current_resource.instance.wait_until_running{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}
      end
    else
      Chef::Log.warn 'Cannot change instance type because machine is not stopped and \'allow_stopping\' is false' unless current_resource.instance_type == new_resource.instance_type
      Chef::Log.warn 'Cannot change user data because machine is not stopped and \'allow_stopping\' is false' unless current_resource.user_data == new_resource.user_data
    end
  end
  converge_by "Changing security groups #{current_resource.instance.security_groups.map{|sg| sg.group_name}} -> #{new_resource.security_groups}" do
    current_resource.instance.modify_attribute(groups: sgs)
  end unless new_resource.security_groups.nil? or current_resource.security_groups == sgs
  converge_by "Changing monitoring #{current_resource.monitoring} -> #{new_resource.monitoring}" do
    if new_resource.monitoring then current_resource.instance.monitor
    else current_resource.instance.unmonitor
    end
  end unless current_resource.monitoring == new_resource.monitoring
  converge_by "Changing API termination protection #{current_resource.disable_api_termination} -> #{new_resource.disable_api_termination}" do
    current_resource.instance.modify_attribute(disable_api_termination: {value: new_resource.disable_api_termination})
  end unless current_resource.disable_api_termination == new_resource.disable_api_termination
  converge_by "Changing instance initiated shutdown behaviour #{current_resource.instance_initiated_shutdown_behavior} -> #{new_resource.instance_initiated_shutdown_behavior}" do
    current_resource.instance.modify_attribute(instance_initiated_shutdown_behavior: {value: new_resource.instance_initiated_shutdown_behavior})
  end unless current_resource.instance_initiated_shutdown_behavior == new_resource.instance_initiated_shutdown_behavior
  converge_by "Changing source destination check #{current_resource.source_dest_check} -> #{new_resource.source_dest_check}" do
    current_resource.instance.modify_attribute(source_dest_check: {value: new_resource.source_dest_check})
  end unless current_resource.source_dest_check == new_resource.source_dest_check
  load_current_resource
end

action :delete do
  if current_resource.exist?
    fail 'The machine is protected and \'allow_stopping\' is false' if current_resource.disable_api_termination and not new_resource.allow_stopping
    converge_by "Enabling API termination in '#{new_resource.name}'" do
      current_resource.instance.modify_attribute(disable_api_termination: {value: false})
    end if current_resource.disable_api_termination
    converge_by "Deleting instance '#{new_resource.name}'" do
      current_resource.instance.terminate
      current_resource.instance.wait_until_terminated{|w| w.delay=new_resource.wait_delay; w.max_attempts=new_resource.wait_attempts}
    end
  end
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
