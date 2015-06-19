
def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource 
  @current_resource = Chef::Resource::AwsEc2RouteTable.new @new_resource.name
  @current_resource.client = Chef::AwsEc2::get_client @new_resource.access_key_id, @new_resource.secret_access_key, @new_resource.region
  @current_resource.vpc_o = Chef::AwsEc2.get_vpc @new_resource.vpc, @current_resource.client
  @current_resource.route_table = get_route_table unless @current_resource.vpc_o.nil?
  unless @current_resource.route_table.nil?
    @current_resource.routes_o = @current_resource.route_table.routes.inject({}) do |acc,re|
      unless re.gateway_id.nil?
        next acc.update({ re.destination_cidr_block => 'gateway' }) if re.gateway_id.start_with? 'igw-'
      end
      acc
    end 
    @current_resource.routes_o = Hash.new if @current_resource.routes_o.empty?
    Chef::Log.warn "Parsed: #{@current_resource.routes_o}"
    Chef::Log.warn "Wanted: #{@new_resource.routes}"
  end
end

action :create do
  converge_by "Creating route table #{@new_resource.name}" do
    rt = @current_resource.vpc_o.create_route_table
    rt.create_tags tags: [{ key: "Name", value: @new_resource.name}]
    @new_resource.updated_by_last_action true
    load_current_resource
  end unless @current_resource.exists?
  @new_resource.routes.each_pair do |cidr, dest|
    converge_by "Creating route entry #{cidr} => #{dest}" do
      create_route cidr, dest
      @new_resource.updated_by_last_action true
    end unless @current_resource.routes_o.has_key? cidr
  end 
  @current_resource.routes_o.each_pair do |cidr, dest|
    converge_by "Deleting route entry #{cidr} => #{dest}" do
      @current_resource.client.delete_route route_table_id: @current_resource.route_table.id, destination_cidr_block: cidr
      @new_resource.updated_by_last_action true
    end unless @new_resource.routes.has_key? cidr
    converge_by "Changing route entry #{cidr} => #{dest} to #{cidr} => #{@new_resource.routes[cidr]}" do
      @current_resource.client.delete_route route_table_id: @current_resource.route_table.id, destination_cidr_block: cidr
      create_route cidr, @new_resource.routes[cidr]
      @new_resource.updated_by_last_action true
    end if @new_resource.routes.has_key? cidr and @new_resource.routes[cidr] != dest
  end
end

action :delete do
  converge_by "Deleting route table #{@new_resource.name}" do
    @current_resource.route_table.delete
    @new_resource.updated_by_last_action true
  end if @current_resource.exists?
end

private

def get_route_table
  Chef::AwsEc2.get_route_table @current_resource.vpc_o, @new_resource.name
   @current_resource.vpc_o.route_tables.select do |rt|
     rt.tags.any? { |t| t.key == 'Name' and t.value == @new_resource.name}
   end.first
end

def create_route cidr, dest
  if dest == 'gateway'
    ig = @current_resource.vpc_o.internet_gateways.first
    raise "VPC does not have an Internet Gatewat and routing thru it was requested" if ig.nil?
    @current_resource.route_table.create_route destination_cidr_block: cidr, gateway_id: ig.id
  else
    raise 'TODO: we only support "gateway"'
  end
end