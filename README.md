COPY FROM: https://gitlab.com/binhdt2611/puppet-demo/
https://turndevopseasier.com/mastering-puppet-implementing-roles-and-profiles-effectively/

# Puppet - Demo Roles and Profiles

This project is a home lab where I explain how to implement Roles and Profiles as the best practice in design pattern for Puppet.

It also provides use cases where we apply Puppet to automate setup tasks for different services. 

Each use case will correspond to blog posts that I wrote at https://turndevopseasier.com. Those blog posts belong to the [Puppet series](https://turndevopseasier.com/puppet-series/) that I created. You can visit my website to check documentation.

# Prerequisite
I'm using Puppet 8 for this development, if you haven't set up, you could follow my [Setup Puppet 8 on Ubuntu 24.04 – Configuration Management for a scaling enterprise](https://turndevopseasier.com/2025/04/10/setup-puppet-8-on-ubuntu-24-04-configuration-management-for-a-scaling-enterprise/) blog to set this up first.

# Structure
Here is the basic structure after setting up roles and profiles if you follow [Mastering Puppet: Implementing Roles and Profiles Effectively In Reality](https://turndevopseasier.com/2025/04/23/mastering-puppet-implementing-roles-and-profiles-effectively/)

```Bash
.
├── Puppetfile
├── README.md
├── data
│   └── nodes
│       ├── <certname-1>.yaml
│       └── <certname-2>.yaml
|        ..... Other configs.
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
    |        ..... Other configs.
    └── roles
        └── manifests
            ├── base.pp
            ├── database.pp
            └── web_server.pp
            ..... Other configs.
```

# Puppet Modules
This project uses Puppetfile and r10k to manage Puppet module dependencies. That reduces the manual installation for each module we use.

r10k will automatically roll out modules to the corresponding environments that we develop.

# Hiera-eyaml
For the sensitive data encrypted in this project, I configure a set of public/private keys locally on the puppet-master to encrypt/decrypt sensitive data. If you want to clone this project to work on it, you will need to create a set of pub/priv keys for yourself, and replace all the encrypted data with your own data.

