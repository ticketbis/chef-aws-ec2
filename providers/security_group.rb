def whyrun_supported?
  true
end

use_inline_resources

def load_current_resource 
  @current_resource = Chef::Resource::AwsEc2SecurityGroup.new @new_resource.name
  @current_resource.client = Chef::AwsEc2::get_client @new_resource.access_key_id, @new_resource.secret_access_key, @new_resource.region
  @current_resource.vpc_o = Chef::AwsEc2.get_vpc @new_resource.vpc, @current_resource.client
  @current_resource.sg = Chef::AwsEc2.get_security_group @current_resource.vpc_o, @new_resource.name unless @current_resource.vpc_o.nil?
  unless @current_resource.sg.nil?
    @current_resource.rules(@current_resource.sg.ip_permissions.map do |p|
      r = Chef::Resource::AwsEc2SecurityGroup::Rule.new
      if p.ip_protocol == 'tcp' then r.protocol = :tcp
      elsif p.ip_protocol == 'udp' then r.protocol = :udp
      elsif p.ip_protocol == '-1' then r.protocol = :all
      elsif p.ip_protocol == 'icmp' then r.protocol = :icmp
      else raise "Unknowk protocol #{p.ip_protocol}"
      end
      if p.from_port == 0 and p.to_port == 65535 then r.port = :all
      elsif p.from_port == p.to_port then r.port = p.from_port
      elsif p.from_port != p.to_port
        Chef::Log.warn "Port ranges unsupported #{p.from_port}-#{p.to_port}. Using '#{p.from_port}'"
        r.port = p.from_port
      else raise "Unknown combination of ports #{p.from_port}-#{p.to_port}"
      end unless r.protocol == :all or r.protocol == :icmp
      # Only one option, giving preference to ids
      r.from = p.ip_ranges.first.cidr_ip unless p.ip_ranges.empty?
      unless p.user_id_group_pairs.empty?
        r.from = Aws::EC2::SecurityGroup.new(p.user_id_group_pairs.first.group_id, {client: @current_resource.client}).tags.select{|t| t.key == 'Name'}.first.value
      end
      r
    end.compact)
  end
end

action :create do
  converge_by "Creating security group '#{@new_resource.name}'" do
    sg = @current_resource.vpc_o.create_security_group group_name: @new_resource.name, description: @new_resource.description
    sg.create_tags tags: [{ key: "Name", value: @new_resource.name}]
    @new_resource.updated_by_last_action true
    load_current_resource
  end unless @current_resource.exists?
  converge_by "Setting security group name to '#{@new_resource.name}'" do
    @current_resource.sg.create_tags tags: [{ key: "Name", value: @new_resource.name}]
    @new_resource.updated_by_last_action true
  end unless @current_resource.sg.tags.any? { |t| t.key == 'Name' and t.value == @current_resource.name }
  (@new_resource.rules - @current_resource.rules).each do |r|
    converge_by "Creating rule from #{r.from} to #{r.port}/#{r.protocol}" do
      @current_resource.sg.authorize_ingress ip_permissions: [convert_rule(r)]
      @new_resource.updated_by_last_action true
    end
  end
  (@current_resource.rules - @new_resource.rules).each do |r|
    converge_by "Deleting rule from #{r.from} to #{r.port}/#{r.protocol}" do
      @current_resource.sg.revoke_ingress ip_permissions: [convert_rule(r)]
      @new_resource.updated_by_last_action true
    end
  end
end

action :delete do
  converge_by "Deleting security group '#{@new_resource.name}'" do
    @current_resource.sg.delete
    @new_resource.updated_by_last_action true
  end if @current_resource.exists?
end

private

def convert_rule rule
  r = {}
  if rule.protocol == :all then r[:ip_protocol] = '-1'
  elsif rule.protocol == :icmp then r[:ip_protocol] = 'icmp'
  elsif rule.protocol == :tcp then  r[:ip_protocol] = 'tcp' 
  elsif rule.protocol == :udp then  r[:ip_protocol] = 'udp'
  end
  if rule.port == :all and (rule.protocol == :tcp or rule.protocol == :udp)
    r[:from_port] = 0
    r[:to_port] = 65535
  elsif rule.port == :all
    r[:from_port] = -1
    r[:to_port] = -1
  else
    r[:from_port] = r[:to_port] = rule.port
  end
  if rule.from == :any then  r[:ip_ranges] = [ { cidr_ip: '0.0.0.0/0' } ]
  elsif rule.from[0] =~ /[0-9]/ then r[:ip_ranges] = [ { cidr_ip: rule.from } ]
  else
    tmp = {}
    tmp[:group_id] = Chef::AwsEc2.get_security_group @current_resource.vpc_o, rule.from
    raise "Unknown Security Group '#{tmp[:group_id]}'" if tmp[:group_id].nil?
    tmp[:group_id] = tmp[:group_id].id
    r[:user_id_group_pairs] = [tmp]
  end
  r
end
