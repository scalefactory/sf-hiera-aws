# sf-hiera-aws

This is an open source project published by The Scale Factory.

We currently consider this project to be archived.

:warning: We’re no longer using or working on this project. It remains available for posterity or reference, but we’re no longer accepting issues or pull requests.

## About

This is a Hiera backend to provide access to the EC2 API for a small number of
resource types. Its purpose is to prevent it from ever being necessary to copy
and paste EC2, RDS, AutoScaling Instance members, and ElastiCache addresses from
the AWS console into Puppet configs anywhere.

## Usage and Setup

To add this backend to hiera, edit `/etc/puppet/hiera.yaml`:

```
:backends:
  - yaml
  - sf_hiera_aws
```

This plugin will attempt to use a machine's IAM role to perform AWS lookups -
this is the recommended method of operation. 

Absent an IAM role, the plugin will fall back to looking up credentials in the
environment. Use `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION`
variables.

The IAM role will need the following permissions:

```
{
    "Version": "2012-10-17",
    "Statement": [
            {
                "Action": [
                    "ec2:DescribeInstances",
                    "rds:DescribeDBInstances",
                    "elasticache:DescribeCacheClusters",
                    "autoscaling:DescribeAutoScalingGroups"
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

The plugin expects to find a configuration file under
`/etc/puppet/sf_hiera_aws.yaml`, defining how we look up named keys.  The keys
at the top level of this file determine the names of the hiera keys the plugin
will provide; the configuration determines how these are looked up.

Additional configuration can be given in files under
`/etc/puppet/sf_hiera_aws.d`, which are evaluated in alphanumerical order. If a
duplicate key is encountered in files evaluated later, this will override the
earlier config.

### Example - EC2 nodes by tag

```
aws_am_search_nodes:
  type: :ec2_instance
  filters:
    - name:   tag:aws:autoscaling:groupName
      values: [ "%{::sf_location}-%{::sf_environment}-search" ]
    - name: instance-state-name
      values: [ 'running' ]
  return:
    - :instance_id
    - :private_ip_address
    - :private_dns_name
```

The value of `return` here is also the default, and so can be omitted. You can
use any of the methods listed at
http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html to obtain other
details from the Instance object.  Calls to this key will return a list of
hashes, each containing `instace_id`, `private_ip_address` and
`private_dns_name` keys.

Note that by default all EC2 instances will be returned, including stopped
instances. To return only the running instances, add a filter as shown in this
example.

### Example - EC2 nodes by tag, single item list

```
aws_am_search_nodes:
  type: :ec2_instance
  filters:
    - name:   tag:aws:autoscaling:groupName
      values: [ "%{::sf_location}-%{::sf_environment}-search" ]
  return: :private_ip_address
```

Here, we pass a single symbol to the `return` argument.  In this case, we'll get
back a list of strings containing private ip addresses (rather than a list of
hashes).



### Example - RDS instance by name

```
aws_am_bullseye_rds:
  type:                   :rds_db_instance
  db_instance_identifier: "%{::sf_location}-%{::sf_environment}-db"
```

Calls to `:rds_db_instance` type keys return the instance identifier, endpoint
address and endpoint port in a hash.

Pass a `return` key with value `:hostname` to have the hostname of the first
matching instance returned.

Pass a `return` key with value `:hostname_and_port` to have a
`"<hostname>:<port>"` string of the first matching instance returned.

### Example - ElastiCache cluster by name

```
aws_am_bullseye_redis:
  type:             :elasticache_cache_cluster
  cache_cluster_id: "%{::sf_location}-%{::sf_environment}-redis"
```

Calls to `:elasticache_cache_cluster` type keys return a list of cache nodes,
their IDs and endpoint address/ports.

Pass a `return` key with value `:hostname` to have a list of hostnames of keys
of all cache nodes matching the cache_cluster_id returned.

Pass a `return` key with value `:hostname_and_port` to have a list of
`"<hostname>:<port>"` strings returned.

### Example - ElastiCache replication group by name

```
aws_app_redis:
  type: :elasticache_replication_group
  replication_group_id: "%{::sf_location}-%{::sf_environment}-redis"
```

Calls to `:elasticache_replication_group` return a list of replication groups,
their primary endpoints and node group members.

Pass a `return` key with value `:primary_endpoint` to have the hostname for the
primary end point of the node group returned.

Pass a `return` key with value `:primary_endpoint_and_port` to have the hostname
and port returned as a colon-separated string.

Pass a `return` key with value `:read_endpoints` to return an array of read
endpoint hostnames, if a `replication_group_id` is specified. Returns `nil` if
`replication_group_id` is unspecified.

Pass a `return` key with value `:read_endpoints_with_ports` to return an array
of read endpoint hostnames and ports as colon delimted strongs. Returns `nil` if
`replication_group_id` is unspecified.

### Example - AutoScaling Instance members

```
---
aws_asg_group:
  type:                     :autoscaling_group
  auto_scaling_group_names: ["euwest1-test-api"]
  return:                   :instance_details_inservice_ip
```

Calls to `:autoscaling_group` return a list of autoscaling groups and
instance-id.

Pass a `return` key with value `:instance_details_inservice_ip` to have the
instance IP's returned for any matching instances in those autoscaling groups
that are in the 'InService' state. This prevents nodes which are coming online,
or have been marked for termination as appearing in this list.

You will need to setup an ASG Lifecycle hook to put the machine into a Waiting
state for slightly more that your puppet run, e.g. 20 minutes.

## Notes

* The order in which items are returned, for example EC2 nodes matching a tag,
  is undefined. If you are using an array of items in a configuration file
  template, for example, you are advised to sort the array in the template. This
  eliminates the likelihood of unnecessary configuration file changes, and the
  consequential unnecessary restart of dependent services.
* By default, all EC2 instances are returned, including those in a non-running
  state. To return only running instances, add a filter on
  `name: instance-state-name` and `values: ['running']` as per the example
  above.
