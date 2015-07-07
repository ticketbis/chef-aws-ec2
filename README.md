# aws-ec2

'aws-ec2' includes LWRP to manage resources from Amazon AWS EC2

## LWRPs

All LWRPs accepts the following parameters:

* region: Amazon region to use
* access_key_id: the access key to use
* secret_access_key: the secret to use

All LWRPs accept actions :create (to create or modify a EC2 resource) and :delete (to delete resource).
Instances and NAT allow actions :start and :stop.


### vpc

Manage VPCs.

#### Parameters

* cidr: the address block for the VPC like 192.168.0.0/16
* instance_tenancy: 'default' or 'dedicated'
* enable_dns_support: true or false (true by default and recommended)
* enable_dns_hostnames: true or false (true by default and recommended)
* internet_gateway: attach a internet gateway to VPC. Creates or reuses an existing
one. true or false (true by default)

### route_table

Manage VPCs route tables

#### Parameters

* vpc: the VPC name to create the route table in (required)
* default_route: the default route, i.e., the route for 0.0.0.0/0. It is 
translated to a rule like '0.0.0.0/0' -> provided value.
* routes: a hash with entries like { cidr -> destination}. CIDR must be a valid
network block or 'default'. 'destination' can be:
  * 'gateway': route thru VPC gateway
  * 'nat@<subnet>': route thru the machine with a NAT AMI in the specified subnet

### subnet

Manage VPC subnets

#### Parameters

* vpc: the VPC name where this subnet resides on
* cidr_block: the CIDR block for the subnet. It must be inside the VPC's cidr_block
* availability_zone: a letter appended to the region to form the availability zone. 'a' by default.
* route_table: the route table to attach to this subnet.
* public_ip: whether to allocate a public IP address to instances in this subnet. true or false. false by default.

### security_group

Manage VPCs security groups

#### Parameters

* vpc: the VPC name to create security group inside
* description: the long description of this security group. By default, 'SG ' + name
* rules: an array of rules. Each rule is a hash with the following keys:
  * protocol: the protocol for the rule. It can be :tcp, :udp, :icmp or :all. :tcp by default.
  * port: the destination port. Unused for :icmp.
  * from: the origin of the packet. It can be :all, a CIDR address or the name of an existing security group.

### keypair

Manage keys used to log into machines

#### Parameters

* publickey: the public key of the key as string

### instance

Manage EC2 instances. 

#### Parameters

* vpc: the VPC name where the instance will be created
* subnet: the subnet in which this instance will be created
* image: the image name. It may be an AMI id (ami-XXXXX) or :nat to create a NAT machine
* instance_type: the instance type to create.
* key_name: the key to install in the instance to allow logging in
* security_groups: an array of security group names to assign to this instance
* user_data: the text snippet that is provided to the instance
* user_data_allow_stop: whether to allow stopping the machine in order to change the user_data. false (by default)
will not stop the machine, so it is not changed. If true, the instance is stopped, the user_data changed and
the machine started again
* monitoring: whether to enable monitoring. true or false. false by default.
* disable_api_termination: whether to allow terminating the machine without disabling the safety measure
* instance_initiated_shutdown_behavior: the action to perform when the machine stops. 'stop' or 'terminate'. 'stop' by default.
* ebs_optimized: whether to optimize EBS. true or false. false by default. Not available on all instance types.
* source_dest_check: whether to check that packets that arrive via an interface are routed to the same interface. 
A safety check to mitigate network attacks, but it must be disabled in NAT machines. true by default.
* allow_stopping: whether to allow to stop the machine to perform some actions. Also, it blocks from deleting the instance.
* wait: whether to wait to some operations to being performed. For example, wait till the machine is ready when created or
wait until the machine is stopped when deleted. true by default.
* wait_delay: seconds between machine status checks. Default, 10 seconds.
* wait_attempts: how many retries to perform before stop checking. A safety net to avoid waiting forever. Default, 30 times.
* assign_eip: whether automatically use or allocate an EIP and be assigned to this instance. On deletion, the EIP
is automatically released and recycled. false by default.
* private_dns_name: the name or array of DNS names that will be created pointing to this intances' private IPv4 address.
* public_dns_name: the name or array of DNS names that will be created pointing to this intances' EIP address.

### nat

A shortcut to create NAT instances. It will pass the appropiate parameters to the 'instance' LWRP.

#### parameters

* vpc: the VPC name where the instance will be created
* subnet: the subnet in which this instance will be created
* key_name: the key to install in the instance to allow logging in
* security_groups: an array of security group names to assign to this instance
* user_data: the text snippet that is provided to the instance
* user_data_allow_stop: whether to allow stopping the machine in order to change the user_data. false (by default)
will not stop the machine, so it is not changed. If true, the instance is stopped, the user_data changed and
the machine started again
* monitoring: whether to enable monitoring. true or false. false by default.
* disable_api_termination: whether to allow terminating the machine without disabling the safety measure
* instance_initiated_shutdown_behavior: the action to perform when the machine stops. 'stop' or 'terminate'. 'stop' by default.
* ebs_optimized: whether to optimize EBS. true or false. false by default. Not available on all instance types.
* allow_stopping: whether to allow to stop the machine to perform some actions. Also, it blocks from deleting the instance.
* wait: whether to wait to some operations to being performed. For example, wait till the machine is ready when created or
wait until the machine is stopped when deleted. true by default.
* wait_delay: seconds between machine status checks. Default, 10 seconds.
* wait_attempts: how many retries to perform before stop checking. A safety net to avoid waiting forever. Default, 30 times.
* assign_eip: whether automatically use or allocate an EIP and be assigned to this instance. On deletion, the EIP
is automatically released and recycled. false by default.
* private_dns_name: the name or array of DNS names that will be created pointing to this intances' private IPv4 address.
* public_dns_name: the name or array of DNS names that will be created pointing to this intances' EIP address.
