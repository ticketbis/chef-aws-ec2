include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  self.current_resource = Chef::Resource.resource_for_node(new_resource.declared_type, node).new @new_resource.name
  @current_resource.client = Chef::AwsEc2::get_client aws_credentials, aws_region
  @current_resource.vpc_o = Chef::AwsEc2.get_vpc @new_resource.vpc, @current_resource.client
  @current_resource.subnet = Chef::AwsEc2.get_subnet @current_resource.vpc_o, @new_resource.name, @current_resource.client
  if @current_resource.exists?
    @current_resource.cidr_block @current_resource.subnet.cidr_block
    @current_resource.availability_zone @current_resource.subnet.availability_zone[-1]
    @current_resource.public_ip @current_resource.subnet.map_public_ip_on_launch
    get_route_table
    # get association and populate route_table_o and route_table
    # @current_resource.route_table_o
    # @current_resource.route_table
  end
end

action :create do
  converge_by "Creating subnet #{@new_resource.name}" do
    opts = {
      cidr_block: @new_resource.cidr_block,
      availability_zone: "#{aws_region}#{@new_resource.availability_zone.downcase}"
    }
    s = @current_resource.vpc_o.create_subnet opts
    s.create_tags tags: [{ key: "Name", value: @new_resource.name}]
    load_current_resource
  end unless @current_resource.exists?
  raise "New CIDR block requested, but cannot change once created" if @current_resource.cidr_block != @new_resource.cidr_block
  raise "New availability zone requested, but cannot change once created" if @current_resource.availability_zone != @new_resource.availability_zone.downcase
  raise "New Public IP assignment policy requested, but cannot change once created" if @current_resource.public_ip != @new_resource.public_ip
  converge_by "Replacing route table to #{@new_resource.route_table}" do
    rt = Chef::AwsEc2.get_route_table @current_resource.vpc_o, @new_resource.route_table
    raise "Subnet '#{@new_resource.route_table}' does not exist" if rt.nil?
    prev_rt = current_resource.vpc_o.route_tables.find{|rt| rt.associations(filters: [{name: 'association.subnet-id', values: [current_resource.id]}]).count > 0}
    if prev_rt.nil?
      rt.associate_with_subnet subnet_id: @current_resource.id
    else
      prev_assoc = prev_rt.associations(filters: [{name: 'association.subnet-id', values: [current_resource.id]}]).first
      prev_assoc.replace_subnet(route_table_id: rt.id)
    end
  end if @current_resource.route_table != @new_resource.route_table
end

action :delete do
  converge_by "Deleting subnet #{@new_resource.name}" do
    @current_resource.subnet.delete
  end if @current_resource.exists?
end

private

def get_route_table
  filter = { name: 'association.subnet-id', values: [@current_resource.id] }
  @current_resource.route_table_o = @current_resource.client.describe_route_tables(filters: [filter])[:route_tables].first
  unless @current_resource.route_table_o.nil?
    t = @current_resource.route_table_o.tags.select { |t| t.key == 'Name' }.first
    @current_resource.route_table t.value unless t.nil?
  end
end

