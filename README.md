# Puppet - Demo Roles and Profiles

This project is a home lab where I explain how to implement Roles and Profiles as the best practice in design pattern for Puppet.

It also provides use cases where we apply Puppet to automate setup tasks for different services. 

Each use case will corresponding to blog posts that I wrote at https://turndevopseasier.com. Those blog posts belong to the Puppet series that I created. You can visit

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

