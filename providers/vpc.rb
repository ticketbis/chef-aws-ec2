include Chef::AwsEc2::Credentials

def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource
  self.current_resource = Chef::Resource.resource_for_node(new_resource.declared_type, node).new @new_resource.name
  @current_resource.client = Chef::AwsEc2::get_client aws_credentials, aws_region
  @current_resource.vpc = Chef::AwsEc2.get_vpc @current_resource.name, @current_resource.client
  unless @current_resource.vpc.nil?
    @current_resource.cidr_block(@current_resource.vpc.cidr_block)
    @current_resource.instance_tenancy(@current_resource.vpc.instance_tenancy)
    @current_resource.enable_dns_support(@current_resource.vpc.describe_attribute(attribute: 'enableDnsSupport')[:enable_dns_support][:value])
    @current_resource.enable_dns_hostnames(@current_resource.vpc.describe_attribute(attribute: 'enableDnsHostnames')[:enable_dns_hostnames][:value])
  end
end

action :create do
  converge_by "VPC #{@current_resource.name} does not exist. Creating..." do
    create_vpc
  end unless @current_resource.exists?
  raise "Current VPC and desired VPC does not have the same CIDR" unless @current_resource.cidr_block == @new_resource.cidr_block
  raise "Current VPC and desired VPC does not have the same instance_tenancy" unless @current_resource.instance_tenancy == @new_resource.instance_tenancy
  converge_by "Changing enable_dns_support to #{@new_resource.enable_dns_support}" do
    @current_resource.vpc.modify_attribute enable_dns_support: { value: @new_resource.enable_dns_support }
  end unless @current_resource.enable_dns_support == @new_resource.enable_dns_support
  converge_by "Changing enable_dns_hostnames to #{@new_resource.enable_dns_hostnames}" do
    @current_resource.vpc.modify_attribute enable_dns_hostnames: { value: @new_resource.enable_dns_hostnames }
  end unless @current_resource.enable_dns_hostnames == @new_resource.enable_dns_hostnames
  attach_igw if @new_resource.internet_gateway and not @current_resource.has_igw?
  converge_by "Detaching internet gateway" do
    @current_resource.vpc.detach_internet_gateway internet_gateway_id: @current_resource.vpc.internet_gateways.first.id
  end if not @new_resource.internet_gateway and @current_resource.has_igw?
end

action :delete do
  converge_by 'Deleting VPC' do
    converge_by 'Deleting VPC internet gateways' do
      @current_resource.vpc.internet_gateways.each { |ig| @current_resource.vpc.detach_internet_gateway internet_gateway_id: ig.id; ig.delete }
    end if @current_resource.vpc.internet_gateways.count > 0
    @current_resource.vpc.delete
  end if @current_resource.exists?
end

private

def create_vpc
  vpc = @current_resource.client.create_vpc cidr_block: @new_resource.cidr_block, instance_tenancy: @new_resource.instance_tenancy
  @current_resource.client.create_tags resources: [vpc[:vpc][:vpc_id]], tags: [{ key: 'Name', value: @new_resource.name }]
  load_current_resource
end

def attach_igw
  if @current_resource.vpc.internet_gateways.count == 0
    id = nil
    @current_resource.client.describe_internet_gateways[:internet_gateways].each do |i|
      if i.attachments.empty?
        id = i[:internet_gateway_id]
        break
      end
    end
    if id.nil?
      converge_by 'Attaching a new internet gateway' do
        id = @current_resource.client.create_internet_gateway[:internet_gateway][:internet_gateway_id]
        @current_resource.vpc.attach_internet_gateway internet_gateway_id: id
      end
    else
      converge_by 'Attaching an available internet gateway' do
        @current_resource.vpc.attach_internet_gateway internet_gateway_id: id
      end
    end
  end
end


