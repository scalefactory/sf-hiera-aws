# Contributing

## Unit Tests

You can run the unit tests with `bundle exec rake test:unit`

The tests live under `spec/` as per the rspec convention, with one spec file
per lookup type.  We use a combination of dependency injection and the mocking
features of the AWS SDK to test the logic inside the hiera back-end.


## Testing For Real

With unit tests in place, you'll want to test against some real infrastructure
at some point too.  The easiest way to do this is using the Hiera CLI tool.

Check out this backend onto your test box. Alongside it, you'll create three
config files.

```
hiera.yaml  scope.yaml  sf-hiera-aws  sf_hiera_aws.yaml
```

`hiera.yaml` should look like:

```
---
:backends:
  - sf_hiera_aws

:logger: console

:aws_sdk:
    :config_file: sf_hiera_aws.yaml
```

`scope.yaml` should contain any variables you interpolate in the other config
files.  For example:

```
---
"::sf_environment": test
"::sf_location": euwest1
```

`sf_hiera_aws.yaml` should be your config for this back-end, as documented
in the README for this project.

To ensure we load the checked out version of this plugin rather than any
installed copy, we set the RUBYLIB environment variable to point at the
project `lib/` folder.

To look up a test key, do the following:

```
$ RUBYLIB=sf-hiera-aws/lib hiera -c ./hiera.yaml -y ./scope.yaml --debug <key>
```


