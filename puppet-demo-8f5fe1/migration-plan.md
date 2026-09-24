# MIGRATION FROM PUPPET TO ANSIBLE

This repository is a Puppet 8 roles-and-profiles control repository for a small Ubuntu-based lab/enterprise-style estate. The migration covers nine node role assignments, reusable profile classes, Hiera YAML and hiera-eyaml data, Puppet Forge dependencies, service configuration, application release automation, monitoring, Consul, MySQL replication, GitLab, Nginx, and the Puppet server/PuppetDB itself. The source is relatively compact, but the migration is **medium-to-high complexity** because it combines stateful database replication, encrypted data, dynamic release logic, monitoring configuration, and a control-plane replacement.

A reasonable first implementation is approximately **8–12 weeks** for one experienced Ansible engineer plus application/database/operations reviewers: 1–2 weeks discovery and design, 3–5 weeks role and service conversion, 1–2 weeks secrets and integration testing, and 2–3 weeks staged rollout and parallel-run remediation. A two-person team can shorten elapsed time, but database, monitoring, and release cutover should remain coordinated.

## Module Migration Plan

This repository contains Puppet manifests organized using the roles-and-profiles pattern. There are no conventional third-party module `manifests/init.pp` entrypoints in the checked-in `site` tree; the deployable units are the custom `profiles::*` and `roles::*` classes below. External Puppet modules are declared in `Puppetfile` and are listed as dependencies rather than as local modules.

### MODULE INVENTORY

**CRITICAL PATH VERIFICATION:**
Only paths present in the supplied repository tree were included. The paths below are custom Puppet class locations, not inferred external module paths.

- **profiles-base**:
    - Description: Common host preparation for every role: custom Facter directories, baseline packages, and `/opt`, `/data`, and `/data/app` directory structure.
    - Path: `site/profiles/manifests/base.pp` and `site/profiles/manifests/base/`
    - Technology: Puppet
    - Key Features: `socat`, `net-tools`, `curl`, `unzip`; filesystem ownership and directory creation; purge behavior for Facter directories.

- **profiles-consul**:
    - Description: Consul agent/server installation and configuration, with a separate consul-template component used by monitoring hosts.
    - Path: `site/profiles/manifests/consul.pp` and `site/profiles/manifests/consul/`
    - Technology: Puppet
    - Key Features: Hiera-driven Consul configuration, server/agent modes, three-node retry join, local script checks, Consul-template files and service configuration.

- **profiles-mysql**:
    - Description: MySQL server provisioning, database/user/grant creation, tunable `mysqld` options, and master/slave behavior.
    - Path: `site/profiles/manifests/mysql.pp` and `site/profiles/manifests/mysql/`
    - Technology: Puppet
    - Key Features: MySQL server, removal of default accounts, demo database, remote admin and replication users, binary/relay logging, and slave replication bootstrap.

- **profiles-nagios**:
    - Description: Nagios Core installation and configuration behind Nginx, including plugins, service ordering, NRPE checks, custom templates, and Consul-template integration.
    - Path: `site/profiles/manifests/nagios.pp` and `site/profiles/manifests/nagios/`
    - Technology: Puppet
    - Key Features: Nagios Core 4.5.9 source archive installation, PHP-FPM/fcgiwrap integration, HTTP basic authentication, NRPE commands, host/service templates, and Nginx virtual host.

- **profiles-nginx**:
    - Description: Nginx reverse proxy for the demo web application and application release services, plus deployment of a compiled `web-demo` binary and systemd unit.
    - Path: `site/profiles/manifests/nginx.pp`
    - Technology: Puppet
    - Key Features: `/data/app/web-demo`, `/etc/systemd/system/web-demo.service`, daemon reload, service management, and proxying to localhost:3000.

- **profiles-gitlab**:
    - Description: Thin wrapper around the Puppet GitLab module to install/configure a GitLab server.
    - Path: `site/profiles/manifests/gitlab.pp`
    - Technology: Puppet
    - Key Features: GitLab role is primarily parameterized through Hiera, including external URL, Rails timezone/email/theme settings, and Sidekiq timeout.

- **profiles-golang**:
    - Description: Go toolchain installation for the web-server role.
    - Path: `site/profiles/manifests/golang.pp`
    - Technology: Puppet
    - Key Features: Delegates to the external Golang Puppet module.

- **profiles-puppetmaster**:
    - Description: Puppet Server/PuppetDB control-plane configuration, including PostgreSQL-backed PuppetDB and CSR helper script.
    - Path: `site/profiles/manifests/puppetmaster.pp`
    - Technology: Puppet
    - Key Features: OpenVox package naming, PuppetDB 8.9.1 package, Puppet Server compatibility assumptions, Java heap settings, database password, and CSR validation template.

- **profiles-release**:
    - Description: Generic application release mechanism that downloads the latest GitLab package, extracts versioned archives, switches a symlink, manages a systemd service, proxies through Nginx, and polls every five minutes.
    - Path: `site/profiles/manifests/release.pp` and `site/profiles/manifests/release/app.pp`
    - Technology: Puppet
    - Key Features: GitLab Releases/Generic Packages API, architecture selection, per-application users/groups, database YAML template, systemd units, Nginx reloads, tags, and cron-driven Puppet runs.

- **roles-base**:
    - Description: Base composition role applied as the parent of all server roles.
    - Path: `site/roles/manifests/base.pp`
    - Technology: Puppet
    - Key Features: Includes `profiles::base`.

- **roles-application**:
    - Description: Application server composition for release automation, Consul agent configuration, and NRPE.
    - Path: `site/roles/manifests/application.pp`
    - Technology: Puppet
    - Key Features: Inherits base and includes application release, Consul, and monitoring agent functionality.

- **roles-consul**:
    - Description: Consul server composition role.
    - Path: `site/roles/manifests/consul.pp`
    - Technology: Puppet
    - Key Features: Base plus Consul server profile.

- **roles-database**:
    - Description: MySQL database role with conditional replication configuration for non-master nodes.
    - Path: `site/roles/manifests/database.pp`
    - Technology: Puppet
    - Key Features: Base plus MySQL, Hiera-controlled `is_master`, and ordering before replication bootstrap.

- **roles-gitlab**:
    - Description: GitLab server composition role.
    - Path: `site/roles/manifests/gitlab.pp`
    - Technology: Puppet
    - Key Features: Base plus GitLab profile.

- **roles-nagios**:
    - Description: Monitoring server composition role.
    - Path: `site/roles/manifests/nagios.pp`
    - Technology: Puppet
    - Key Features: Nagios, NRPE, Consul agent, Consul-template, and explicit Consul-to-template ordering.

- **roles-puppetmaster**:
    - Description: Puppet master/PuppetDB server composition role.
    - Path: `site/roles/manifests/puppetmaster.pp`
    - Technology: Puppet
    - Key Features: Base plus PuppetDB/control-plane profile.

- **roles-web-server**:
    - Description: Web server composition role for Go, Nginx, demo application, and Consul agent.
    - Path: `site/roles/manifests/web_server.pp`
    - Technology: Puppet
    - Key Features: Base, Golang, Nginx reverse proxy, and Consul.

### Infrastructure Files

- `Puppetfile`: Puppet Forge dependency lock-by-convention; must be translated to Ansible collections, packages, roles, or locally managed tasks.
- `environment.conf`: Sets the Puppet module path to `site:modules`; replace with Ansible project/collection layout and inventory/group variables.
- `hiera.yaml`: Defines YAML and hiera-eyaml hierarchy, per-node and per-group precedence, and encrypted secret lookup. This is the main source for Ansible inventory/group_vars/host_vars and Vault integration.
- `manifests/sites.pp`: Puppet entrypoint; applies the role selected by `server::role` from Hiera and sets the execution path for `exec` resources.
- `r10k.yaml`: Git-based Puppet environment deployment to `/etc/puppetlabs/code/environments`; replace with Ansible repository CI/CD and inventory/configuration promotion.
- `data/nodes/*.yaml`: Node role assignments and host-specific configuration for application, Consul, database, GitLab, Nagios, Puppet master, and web nodes.
- `data/consul/default.yaml`, `data/mysql/default.yaml`, `data/nagios/default.yaml`: Group/default service configuration and merge rules.
- `data/secrets/*.eyaml`: Encrypted per-node/shared Hiera data; migrate without decrypting into source control and rotate exposed credentials.
- `site/profiles/files/`: Static binaries, Go source/module metadata, systemd unit, shell script, Nagios/Consul templates, and application assets that need controlled deployment.
- `site/profiles/templates/`: Puppet ERB templates for Consul-template, Puppet CSR checking, and application database configuration; convert to Jinja2 templates.
- `site/profiles/lib/` and `site/roles/lib/`: Custom Puppet Ruby/Facter extensions, including latest package version lookup and group assignment; replace with Ansible facts, filters, API tasks, or a tested plugin.
- `x2a-rules/d5872732-f37d-4221-8ddd-af1d68455083.md`: Migration-rule artifact whose contents were not required to identify the Puppet topology; review before finalizing any automated conversion assumptions.

### Target Details

- **Operating System**: Ubuntu 24.04 is explicitly indicated by the README and Puppet master comments. Package paths, PHP-FPM socket, systemd usage, and Puppet/OpenVox package names reinforce Ubuntu/Debian assumptions. Preserve Ubuntu 24.04 as the primary target and test package/service names explicitly.
- **Virtual Machine Technology**: Not specified. Hostnames and private addressing suggest a lab or internal virtualized environment, but no VMware, VirtualBox, KVM, Hyper-V, or cloud-init configuration is present.
- **Cloud Platform**: Not specified. GitLab SaaS APIs are used for application artifacts, but no AWS, Azure, or GCP infrastructure integration is shown.

## Migration Approach

Create an Ansible project with an inventory representing the named nodes and groups such as `consul_servers`, `databases`, `application`, `gitlab`, `nagios`, `puppetmaster`, and `web`. Use roles for the deployable profiles (`base`, `consul`, `mysql`, `nagios`, `nginx`, `gitlab`, `golang`, `puppetmaster`, and `release`) and compose them in role-specific plays. Convert Hiera precedence into `group_vars`, `host_vars`, and explicit defaults, documenting precedence rather than relying on implicit merges. Use check mode, Molecule or equivalent isolated tests, and staged inventory execution.

### Key Dependencies to Address

- **puppetlabs-mysql 16.2.0**: Replace with `community.mysql` modules plus explicit Ubuntu MySQL package/service/configuration tasks. Implement users, grants, databases, and replication with idempotent tasks and a carefully tested bootstrap procedure.
- **puppetlabs-nginx 6.0.1**: Replace with an Ansible Nginx role or local role using Jinja2 vhost templates, `nginx -t`, handlers, and service reloads.
- **puppet-consul 9.2.0 / puppet-hashi_stack 3.3.0**: Use a pinned Ansible Consul role or local tasks for installation, systemd, HCL/JSON configuration, cluster membership, ACL/encryption handling, and Consul-template.
- **puppetlabs-nagios_core 1.0.3 and puppet-nrpe 6.0.0**: Replace with a tested Nagios/NRPE role or package/source install tasks. Preserve plugin paths, command definitions, templates, and server/client differences.
- **puppet-gitlab 10.3.0**: Prefer GitLab Omnibus package/repository configuration through Ansible, with a controlled `gitlab-ctl reconfigure` step and backup/restore validation.
- **dp-golang 1.2.8**: Replace with an Ubuntu package or pinned Go archive role; define the required Go version rather than relying on module defaults.
- **puppetlabs-puppetdb 8.1.0, puppetlabs-postgresql 10.6.1, and OpenVox packages**: These support the current control plane. Decide whether the Puppet master/PuppetDB host is decommissioned after migration or temporarily maintained; Ansible should not silently reproduce the Puppet control plane unless a coexistence period requires it.
- **puppetlabs-apt 10.0.1, stdlib 9.7.0, concat 9.1.0, inifile 6.2.0, firewall 8.2.0, archive 7.1.0, and systemd 8.3.1**: Replace with `ansible.builtin` package/file/service/template/archive/systemd tasks, `community.general` where needed, and explicit firewall tasks. Pin collection versions in `requirements.yml`.
- **GitLab release API and custom `get_latest_pkg_version` function**: Replace with authenticated `uri` calls, validated JSON parsing, checksum/signature verification, `get_url`, `unarchive`, symlink switching, and deployment handlers. Avoid arbitrary remote downloads.
- **Puppet cron/tag execution model**: Replace with Ansible Automation Platform/AWX schedules or CI/CD jobs. Do not run `ansible-playbook` blindly from every managed host.

### Security Considerations

- **Hardcoded credentials**: `profiles::mysql` visibly contains a MySQL root password, admin password, replication password, and demo database password. Treat all as compromised; rotate them and move to Ansible Vault or an external secret manager before migration. Do not copy literals into `group_vars`.
- **Consul encryption key**: `data/consul/default.yaml` contains a plaintext Consul `encrypt` key despite comments recommending eyaml. Rotate the gossip key, store it in Vault, and distribute it only to required nodes.
- **Hiera-eyaml secrets**: `data/secrets/app-01.srv.local.eyaml`, `nagios-server.srv.local.eyaml`, `puppet-master.srv.local.eyaml`, and `shared.eyaml` use PKCS7 encryption with private/public key paths under `/etc/puppetlabs/puppet/eyaml`. Export only required values into Ansible Vault/external secrets, establish key ownership and backup procedures, and rotate keys during cutover.
- **Application database configuration**: The release profile renders database credentials into `database_config.yaml`. Use restrictive file permissions, `no_log` on secret-bearing tasks, and preferably environment files or a secret manager rather than command-line arguments or world-readable templates.
- **GitLab/API access**: The release process retrieves artifacts from GitLab. Identify whether tokens exist in the encrypted app secrets, use short-lived scoped tokens, and validate TLS, checksums, project IDs, and downloaded archive names.
- **Nagios credentials and HTTP exposure**: Nagios is served on port 80 with HTTP basic authentication and PHP/FastCGI paths. Move to HTTPS, securely generate/manage htpasswd data, restrict management access, and review CGI/PHP exposure and Nginx headers.
- **Consul exposure**: `client_addr: 0.0.0.0` and local script checks expand attack surface. Restrict listener addresses/firewall rules, use ACLs/TLS where appropriate, and review every local check for command injection.
- **Privilege and execution**: Puppet `exec` resources and root-owned scripts perform replication, reloads, and release operations. Use narrowly scoped Ansible tasks, validate inputs, avoid shell where modules suffice, and preserve file modes/ownership.
- **Network/database exposure**: MySQL binds to `0.0.0.0` and grants users access to `192.168.68.%`. Restrict bind addresses and source networks, use least-privilege grants, and validate replication traffic firewall rules.
- **Supply chain**: Puppet dependencies, GitLab releases, source archives, and the checked-in compiled `web-demo` binary need provenance and checksum verification. Pin versions and record approved artifact hashes.

### Technical Challenges

- **Puppet-to-Ansible execution semantics**: Puppet's catalog ordering, containment, refresh notifications, tags, and automatic convergence do not map one-to-one. Model dependencies with handlers, `block/rescue`, explicit task ordering, and separate converge/configure plays.
- **Hiera merge behavior**: `profiles::consul::configs`, MySQL overrides, release applications, and secrets use different merge rules. Build a documented variable model and test each node's rendered configuration against a Puppet reference snapshot.
- **MySQL replication**: The source uses a shell bootstrap with a marker file and has master/slave distinctions. Confirm replication topology, credentials, GTID/binlog policy, existing data, failover expectations, and idempotent re-run behavior before changing production databases.
- **Dynamic application releases**: Latest-release lookup, architecture-specific archive names, symlink changes, service restarts, Nginx reloads, and five-minute polling need a deliberate deployment workflow. Prefer centrally scheduled deployments with rollback and health checks.
- **Monitoring configuration**: Nagios, NRPE, custom templates, PHP-FPM, fcgiwrap, and Consul-template span multiple packages and hosts. Establish a configuration validation gate before restarting Nagios or Nginx.
- **Puppet control-plane retirement**: The Puppet master profile configures PuppetDB and OpenVox-specific package names. Ansible migration must include agent disablement, certificate/CSR lifecycle decisions, inventory bootstrap, and a rollback window.
- **Custom Ruby/Facter behavior**: `assign_group` and `get_latest_pkg_version` may encode behavior not visible in the profile entrypoints. Reimplement and test them before removing Puppet facts or release automation.
- **Static artifacts and templates**: Binary files, Go source, shell scripts, ERB templates, and service units require ownership, mode, checksum, and lifecycle decisions. The binary's build provenance is not shown.
- **Ambiguous node naming**: Hiera comments refer to `consul-01` through `consul-03`, while the supplied node files include `consul-server.yaml` only. Resolve the real inventory/certname mapping before automation.

### Migration Order

1. **Inventory, secrets, and base**: Establish Ubuntu 24.04 connectivity, host groups, Ansible Vault/external secret integration, package repositories, users, directories, firewall baseline, and validation facts.
2. **Consul**: Migrate the three-server/agent topology and secure gossip/TLS/ACL settings early because other services use Consul and Consul-template.
3. **Nginx and Go/web demo**: Convert the low-state web path, systemd service, static artifact deployment, and proxy health checks.
4. **GitLab**: Migrate the standalone GitLab host with backup/restore and URL validation; it is also an artifact source for releases.
5. **MySQL master then replicas**: Migrate database configuration and users on the master, validate backup/restore, then perform controlled replica conversion and replication verification.
6. **Application release role**: Implement artifact authentication, checksum validation, database configuration, systemd, symlink rollback, and scheduled deployment after GitLab and database contracts are stable.
7. **Nagios/NRPE**: Migrate monitoring after service endpoints stabilize; use configuration tests and parallel monitoring to avoid losing alert coverage.
8. **Puppet master/PuppetDB retirement**: Keep the existing control plane available during parallel runs, then disable agents, archive required Puppet data, revoke/retire certificates, and decommission only after rollback criteria are met.

### Assumptions

- The target operating system is Ubuntu 24.04, although the complete node OS matrix was not provided.
- The repository is a lab/demo-derived control repository; production availability, sizing, backup, and HA requirements must be confirmed.
- The listed node YAML files are representative of the actual inventory, but Consul node identities and all hostnames/IPs require confirmation.
- No cloud, VM, load-balancer, DNS, or external firewall provider is specified; these are outside this plan unless discovered during implementation.
- The Puppet Forge modules are external and their internal behavior is not reproduced here; equivalent Ansible roles must be selected and tested.
- The contents and key names of encrypted eyaml files were not decrypted; secret inventory and rotation must be performed securely by authorized operators.
- The MySQL replication shell script, Nagios templates, Consul-template files, systemd units, ERB templates, and custom Ruby/Facter code require implementation-level review before production cutover.
- `profiles::release::applications` is intended to be deep-merged with secret values, but the full application secret schema is not visible in the reviewed node file.
- The repository uses a hardcoded demo application and a GitLab project ID; ownership, release policy, authentication, and rollback expectations are not specified.
- The presence of `puppetlabs-postgresql` in the Puppetfile does not prove an application PostgreSQL server is managed here; the visible database profile manages MySQL, while the application points to `todo-postgres.srv.local`. This dependency and external PostgreSQL ownership must be clarified.
- Firewall rules, TLS certificates, DNS records, backups, monitoring notification targets, and service-level objectives are not defined in the reviewed files.
- Migration should initially preserve behavior, including service names, ports, paths, and file modes, before undertaking modernization.
- Team ownership is assumed to be split among platform/Ansible, database, monitoring, security/secrets, and application teams. Each team should approve its role's acceptance tests and rollback plan.
- The migration should use a branch-based CI pipeline with linting, YAML validation, Ansible check mode, secret scanning, Molecule/integration tests, peer review, and staged promotion from lab to canary to all nodes.
