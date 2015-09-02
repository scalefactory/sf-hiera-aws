# sf-hiera-aws

## About

This is a Hiera backend to provide access to the EC2 API for a small number of resource types. Its purpose is to prevent it from ever being necessary to copy and paste EC2, RDS and ElastiCache addresses from the AWS console into Puppet configs anywhere.

## Usage and Setup

To add this backend to hiera, edit `/etc/puppet/hiera.yaml`:

```
:backends:
  - yaml
  - sf_hiera_aws
```

This plugin will attempt to use a machine's IAM role to perform AWS lookups - this is the recommended method of operation. 

Absent an IAM role, the plugin will fall back to looking up credentials in the environment. Use `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION` variables.

The IAM role will need the following permissions:

```
{
    "Version": "2012-10-17",
    "Statement": [
            {
                "Action": [
                    "ec2:DescribeInstances",
                    "rds:DescribeDBInstances",
                    "elasticache:DescribeCacheClusters"
                ],
                "Effect": "Allow",
                "Resource": [
                    "*"
                ]
            }
    ]
}
```

## Configuration

The plugin expects to find a configuration file under `/etc/puppet/sf_hiera_aws.yaml`, defining how we look up named keys.  The keys at the top level of this file determine the names of the hiera keys the plugin will provide; the configuration determines how these are looked up.

### Example - EC2 nodes by tag

```
aws_am_search_nodes:
  type: :ec2_instance
  filters:
    - name:   tag:aws:autoscaling:groupName
      values: [ "%{::sf_location}-%{::sf_environment}-search" ]
  return:
    - :instance_id
    - :private_ip_address
    - :private_dns_name
```

The value of `return` here is also the default, and so can be omitted. You can use any of the methods listed at http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html to obtain other details from the Instance object.


### Example - RDS instance by name

```
aws_am_bullseye_rds:
  type:                   :rds_db_instance
  db_instance_identifier: "%{::sf_location}-%{::sf_environment}-db"
```

Calls to `:rds_db_instance` type keys return the instance identifier, endpoint address and endpoint port.

### Example - ElastiCache cluster by name

```
aws_am_bullseye_redis:
  type:             :elasticache_cache_cluster
  cache_cluster_id: "%{::sf_location}-%{::sf_environment}-redis"
```

Calls to `:elasticache_cache_cluster` type keys return a list of cache nodes, their IDs and endpoint address/ports.

