name 'aws-ec2'
maintainer 'Alberto Tablado'
maintainer_email 'alberto.tablado@ticketbis.com'
license 'Apache v2.0'
source_url 'https://github.com/ticketbis/chef-aws-ec2'
description 'Manage resources in AWS EC2'
long_description IO.read(File.join(
  File.dirname(__FILE__), 'README.md'
  )
)
version '0.2.0'

depends 'aws-base'
depends 'aws-route53'

