BDE Deployment Script for OpenStack
===================================

Usage
-----

After you run `terraform apply` on this configuration, it will output the
floating IP address assigned to the exposed Docker node (which is the manager).
After your instance started, you can access the Swarm UI application on the
port 88. You will also get an IP address to a bastion which allows you to
connect using SSH.

First set the required environment variables for the OpenStack provider by
sourcing the [credentials file](http://docs.openstack.org/cli-reference/content/cli_openrc.html).

```
source openrc
```

Before starting this script, you need to generate an SSH key dedicated for this
deployment:

```
ssh-keygen -f ~/.ssh/id_rsa.terraform
```

Afterwards run with a command like this:

```
terraform apply \
  -var 'external_gateway=0229c96d-90e6-431f-bf44-563285a0e6d4'
```

*Note:* You will need to replace the external gateway id by your own network id
used to get an external IP address. You may also need to change the "pool"
variable to the name of this network.
