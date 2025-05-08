# Puppet - Demo Roles and Profiles

This project explains how to implement Roles and Profiles as the best practice in design pattern for Puppet.

# Structure
Here is the basic structure after setting up roles and profiles

```Bash
.
├── Puppetfile
├── README.md
├── data
│   └── nodes
│       ├── db-01.srv.local.yaml
│       └── web-01.srv.local.yaml
├── environment.conf
├── hiera.yaml
├── manifests
│   └── sites.pp
├── r10k.yaml
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


# Install dependencies Puppet modules (Optional)
I have used several Puppet Forge modules when implementing this demo.

Later, I have added Puppetfile and r10k to manage these modules in environments. You don't have to run these manual commands below if you use r10k.

Otherwise, if you don't use r10k and just follows [Mastering Puppet: Implementing Roles and Profiles Effectively In Reality](https://turndevopseasier.com/2025/04/23/mastering-puppet-implementing-roles-and-profiles-effectively/) only, when we set up this project, please run these commands:

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


