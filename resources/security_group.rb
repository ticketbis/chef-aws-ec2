actions :create, :delete

default_action :create

attribute :name, kind_of: String, name_attribute: true
attribute :vpc, kind_of: String, required: true
attribute :description, kind_of: String, default: '_default_'
attribute :rules, kind_of: [Array, Hash], default: []
attribute :region, kind_of: String, required: true
attribute :access_key_id, kind_of: String, required: true
attribute :secret_access_key, kind_of: String, required: true

attr_accessor :client, :vpc_o, :sg

def exists?
  not sg.nil?
end

def id
  sg.id unless sg.nil?
end

PROTOCOLS = [:all, :icmp, :tcp, :udp]

class Rule
  attr_accessor :protocol, :port, :from
  
  def initialize protocol: :tcp, port: nil, from: nil
    self.protocol = protocol
    self.port = port
    self.from = from
  end

  def protocol= protocol=:tcp
    @protocol = protocol
    @protocol = :tcp if @protocol.nil?
    raise Chef::Exceptions::ValidationFailed, "Invalid protocol '#{@protocol}'" unless PROTOCOLS.member? @protocol
  end

  def port= port=:all
    @port = port
    @port = :all if @port.nil?
  end

  def from= from=:any
    @from = from
    @from = :any if @from.nil? or @from == '0.0.0.0/0'
  end

  def hash
    @protocol.hash + @port.hash + @from.hash
  end

  def == other
    @protocol == other.protocol and @port == other.port and @from == other.from
  end
  alias eql? ==

end

def after_created
  description "SG #{name}" if description == '_default_'
  rules [rules] if rules.instance_of? Hash
  rules(rules.map do |r|
    next unless r.instance_of? Hash
    Rule.new protocol: r[:protocol], port: r[:port], from: r[:from]
  end.compact)
end