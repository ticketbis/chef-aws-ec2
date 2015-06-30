include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  self.current_resource = Chef::Resource.resource_for_node(new_resource.declared_type, node).new @new_resource.name
  @current_resource.client = Chef::AwsEc2::get_client aws_credentials, aws_region
  @current_resource.vpc_o = Chef::AwsEc2.get_vpc @new_resource.vpc, @current_resource.client
  @current_resource.route_table = get_route_table unless @current_resource.vpc_o.nil?
  unless @current_resource.route_table.nil?
    @current_resource.routes_o = @current_resource.route_table.routes.inject({}) do |acc,re|
      if !re.gateway_id.nil?
        next acc.update({ re.destination_cidr_block => 'gateway' }) if re.gateway_id.start_with? 'igw-'
      elsif !re.instance_id.nil?
        instance = current_resource.client.describe_instances(instance_ids: [re.instance_id]).reservations.first.instances.first
        image = Chef::AwsEc2.get_image(aws_region, 'nat')
        if instance.image_id == image
          subnet = Aws::EC2::Subnet.new(instance.subnet_id, client: current_resource.client)
          fail "An extrange error has occurred. I cannot find the subnet '#{instance.subnet_id}' in which instance '#{instance.instance_id}' lives" if subnet.nil?
          name = subnet.tags.find{|t| t.key == 'Name'}.value
          fail "'#{subnet.id}' subnet's name not found" if name.nil?
          next acc.update({ re.destination_cidr_block => "nat@#{name}"})
        else
          fail "Routing thur a non-NAT machine"
        end
      end
      acc
    end
    @current_resource.routes_o = Hash.new if @current_resource.routes_o.empty?
  end
end

action :create do
  converge_by "Creating route table #{@new_resource.name}" do
    rt = @current_resource.vpc_o.create_route_table
    rt.create_tags tags: [{ key: "Name", value: @new_resource.name}]
    load_current_resource
  end unless @current_resource.exists?
  rt = massage_routes new_resource.routes
  rt.each_pair do |cidr, dest|
    converge_by "Creating route entry #{cidr} => #{dest}" do
      create_route cidr, dest
    end unless @current_resource.routes_o.has_key? cidr
  end
  @current_resource.routes_o.each_pair do |cidr, dest|
    converge_by "Deleting route entry #{cidr} => #{dest}" do
      @current_resource.client.delete_route route_table_id: @current_resource.route_table.id, destination_cidr_block: cidr
    end unless rt.has_key? cidr
    converge_by "Changing route entry #{cidr} => #{dest} to #{cidr} => #{@new_resource.routes[cidr]}" do
      @current_resource.client.delete_route route_table_id: @current_resource.route_table.id, destination_cidr_block: cidr
      create_route cidr, @new_resource.routes[cidr]
    end if rt.has_key? cidr and rt[cidr] != dest
  end
end

action :delete do
  converge_by "Deleting route table #{@new_resource.name}" do
    @current_resource.route_table.delete
  end if @current_resource.exists?
end

private

def get_route_table
  Chef::AwsEc2.get_route_table @current_resource.vpc_o, @new_resource.name
   @current_resource.vpc_o.route_tables.select do |rt|
     rt.tags.any? { |t| t.key == 'Name' and t.value == @new_resource.name}
   end.first
end

def massage_routes rt
  res = {}
  rt['default'] = new_resource.default_route if new_resource.default_route
  rt.each do |cidr, dest|
    cidr = '0.0.0.0/0' if cidr == 'default'
    res[cidr] = dest
  end
  res
end

def create_route cidr, dest
  case dest
  when 'gateway'
    ig = @current_resource.vpc_o.internet_gateways.first
    raise "VPC does not have an Internet Gatewat and routing thru it was requested" if ig.nil?
    @current_resource.route_table.create_route destination_cidr_block: cidr, gateway_id: ig.id
  when /^nat@(.*)/
   subnet = Chef::AwsEc2.get_subnet(current_resource.vpc_o, $1)
   fail "Unable to find subnet '#{$1}' in VPC '#{new_resource.vpc}'" if subnet.nil?
   # get NAT machine in the subnet
   image_id = Chef::AwsEc2.get_image(aws_region, 'nat')
   fail "Unable to find image 'nat' in region '#{aws_region}'" if image_id.nil?
   instance = current_resource.client.describe_instances(
    filters: [
      { name: 'subnet-id', values: [subnet.id]},
      { name: 'image-id', values: [image_id]}
    ]
    ).reservations.first.instances.first
   fail "Unable to find a NAT machine in subnet '#{$1}' in VPC '#{new_resource.vpc}'" if instance.nil?
   @current_resource.route_table.create_route destination_cidr_block: cidr, instance_id: instance.instance_id
  else
    raise 'TODO: we only support "gateway"'
  end
end
