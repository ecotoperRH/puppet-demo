# Puppet - Demo Roles and Profiles

This project explains how to implement Roles and Profiles as the best practice in design pattern for Puppet.

# Structure
Here is the basic structure after setting up roles and profiles

```Bash
.
├── data
│   └── nodes
│       ├── db-01.srv.local.yaml
│       └── web-01.srv.local.yaml
├── environment.conf
├── hiera.yaml
├── manifests
│   └── sites.pp
├── readme.md
└── site
    ├── profiles
    │   ├── files
    │   │   └── nginx
    │   │       ├── web-demo
    │   │       │   ├── go.mod
    │   │       │   ├── main.go
    │   │       │   └── web-demo
    │   │       └── web-demo.service
    │   └── manifests
    │       ├── base
    │       │   ├── facts.pp
    │       │   ├── packages.pp
    │       │   └── structure.pp
    │       ├── base.pp
    │       ├── golang.pp
    │       ├── mysql.pp
    │       └── nginx.pp
    └── roles
        └── manifests
            ├── base.pp
            ├── database.pp
            └── web_server.pp
```
# Install dependencies Puppet modules
To implement this demo, I have installed a few Puppet Modules from Puppet Forge so that we don't have to write our own modules. Therefore, when we set up this project, run these commands:

1. Install: [db-golang](https://forge.puppet.com/modules/dp/golang/readme) module
```bash
$ wget -O ~/dp-golang-1.2.8.tar.gz https://github.com/danielparks/puppet-golang/releases/download/v1.2.8/dp-golang-1.2.8.tar.gz

$ sudo /opt/puppetlabs/bin/puppet module install ~/dp-golang-1.2.8.tar.gz
```

2. Install: [puppet-nginx](https://forge.puppet.com/modules/puppet/nginx/readme)
```bash
$ sudo /opt/puppetlabs/bin/puppet module install puppet-nginx
```

2. Install: [puppetlabs-apt](https://forge.puppet.com/modules/puppetlabs/apt/readme)
```bash
$ sudo /opt/puppetlabs/bin/puppet module install puppetlabs-apt
```

For more information, I've written a blog at [Mastering Puppet: Implementing Roles and Profiles Effectively In Reality](https://turndevopseasier.com/2025/04/23/mastering-puppet-implementing-roles-and-profiles-effectively/) to demonstrate this project.


NOTE: In the future, I may add a guide to implement R10K to manage this project as source code to deploy it into multiple environments, and also manage these modules through a Puppetfile instead of installing manually like this.

