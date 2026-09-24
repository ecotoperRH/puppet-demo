---
source-path: site/profiles/manifests/mysql.pp
---

# Migration Plan: profiles-mysql

**TLDR**: `profiles::mysql` provisions a MySQL server through `mysql::server`, installs the client through `mysql::db[my-demo-db]`, and manages the `my-demo-db` database, user, and grant. Master nodes additionally manage `db_admin` and `repl_user` accounts. Non-master nodes `db-02.srv.local` and `db-03.srv.local` deploy and execute `profiles::mysql::configure_replication`. Hiera source data must be revalidated because the supplied structured analysis does not include the literal YAML values or confirm the reported deep-merge hierarchy. Passwords and any discovered replication credentials must be migrated to Ansible Vault.

## Service Type and Instances

**Service Type**: Relational database server — MySQL

**Configured Instances**:

- **MySQL server**
  - Service resource: `mysqld`
  - Configuration source: `mysql/my.cnf.epp`
  - Managed option dictionary: `profiles::mysql::override_options`
  - Default datadir: `/var/lib/mysql` through dependency-module defaults unless overridden by the effective `mysqld.datadir`
  - Effective option keys:
    - `mysqld.bind_address`: literal Hiera value requires source verification
    - `mysqld.datadir`: literal Hiera value requires source verification
    - `mysqld.log_error`: literal Hiera value requires source verification
    - `mysqld.pid_file`: literal Hiera value requires source verification
    - `mysqld.server_id`: `'1'` by reported default, `'2'` on `db-02.srv.local`, and `'3'` on `db-03.srv.local`; verify against source YAML
    - `mysqld.innodb_flush_log_at_trx_commit`: `'1'` by reported default and `'2'` on both replicas; verify against source YAML
    - `mysqld.sync_binlog`: literal Hiera value requires source verification
    - `mysqld.log_bin`: literal Hiera value requires source verification
    - `mysqld.relay_log`: literal Hiera value requires source verification
    - `mysqld_safe.log_error`: literal Hiera value requires source verification
  - Service management: dependency-module parameters `manage_service` and `real_service_manage`
  - Restart behavior: dependency-module parameter `restart`; resolved value is not available in the supplied analysis

- **`my-demo-db`**
  - Database resource: `mysql_database[my-demo-db]`
  - User resource: `mysql_user[${user}@${host}]`
  - Grant resource: `mysql_grant[${user}@${host}/${table}]` when `ensure == 'present'`
  - Database name: `my-demo-db`
  - User, host, table, password, ensure, and privilege values: unresolved; obtain from `profiles::mysql` and `mysql::db` defaults or Hiera
  - Database password: migrate to Ansible Vault and protect account tasks with `no_log: true`

- **Master administrative account**
  - Account: `db_admin@192.168.68.%`
  - Grant target: `db_admin@192.168.68.%/*.*`
  - Created only when `is_master` is true
  - Password and exact privileges: unresolved; obtain from source parameters or Hiera and store the password in Ansible Vault

- **Master replication account**
  - Account: `repl_user@192.168.68.%`
  - Grant target: `repl_user@192.168.68.%/*.*`
  - Created only when `is_master` is true
  - Password and exact privileges: unresolved; obtain from source parameters or Hiera and store the password in Ansible Vault

- **Replica configuration on `db-02.srv.local`**
  - `is_master`: reported as `false`; verify against source YAML
  - Configuration class: `profiles::mysql::configure_replication`
  - Script destination: `$configure_repl_script`; unresolved
  - Execution resource: `exec[configure_replication]`
  - Executable lookup: Puppet `$facts['path']`
  - Replication credentials: none confirmed by the supplied analysis; inspect the script and Hiera before adding Vault variables

- **Replica configuration on `db-03.srv.local`**
  - `is_master`: reported as `false`; verify against source YAML
  - Configuration class: `profiles::mysql::configure_replication`
  - Script destination: `$configure_repl_script`; unresolved
  - Execution resource: `exec[configure_replication]`
  - Executable lookup: Puppet `$facts['path']`
  - Replication credentials: none confirmed by the supplied analysis; inspect the script and Hiera before adding Vault variables

## File Structure

**MANDATORY: Preserve this section from the original plan.**

```text
site/roles/manifests/database.pp
site/profiles/manifests/mysql.pp
site/profiles/manifests/mysql/configure_replication.pp
migration-dependencies/mysql/manifests/server.pp
migration-dependencies/mysql/manifests/server/config.pp
migration-dependencies/mysql/manifests/server/install.pp
migration-dependencies/mysql/manifests/server/managed_dirs.pp
migration-dependencies/mysql/manifests/server/installdb.pp
migration-dependencies/mysql/manifests/server/service.pp
migration-dependencies/mysql/manifests/server/root_password.pp
migration-dependencies/mysql/manifests/server/providers.pp
migration-dependencies/mysql/manifests/server/account_security.pp
migration-dependencies/mysql/manifests/client.pp
migration-dependencies/mysql/manifests/client/install.pp
migration-dependencies/mysql/manifests/bindings.pp
migration-dependencies/mysql/manifests/bindings/client_dev.pp
migration-dependencies/mysql/manifests/bindings/daemon_dev.pp
migration-dependencies/mysql/manifests/db.pp
mysql/my.cnf.epp
mysql/my.cnf.pass.epp
data/mysql/default.yaml
data/nodes/db-02.srv.local.yaml
data/nodes/db-03.srv.local.yaml
data/secrets/*.eyaml
```

The supplied directory listing does not provide filesystem paths for the two logical template names. Locate them in the Puppet dependency module.

## Module Explanation

The module performs operations in the following order.

1. **`roles::database`** (`site/roles/manifests/database.pp`)
   - Inherits `roles::base`.
   - Includes `profiles::mysql`.
   - On non-master nodes, orders `Class['profiles::mysql']` before `Class['profiles::mysql::configure_replication']`.
   - Base-role resources are outside the supplied MySQL execution branch.

2. **`profiles::mysql`** (`site/profiles/manifests/mysql.pp`)
   - Declares `mysql::server 'mysql::server'`.
   - Declares `mysql::db 'my-demo-db'`.
   - Creates master-only administrative and replication resources.
   - Applies dependency-module server, client, database, provider, account-security, and service behavior.

3. **`mysql::server`** (`migration-dependencies/mysql/manifests/server.pp`)
   - Establishes server parameters and lifecycle anchors.
   - Includes the following classes in dependency-module execution order:
     - `mysql::server::config`
     - `mysql::server::install`
     - `mysql::server::managed_dirs`
     - `mysql::server::installdb`
     - `mysql::server::service`
     - `mysql::server::root_password`
     - `mysql::server::providers`
     - `mysql::server::account_security` when enabled
   - Uses anchors `mysql::server::start` and `mysql::server::end`.

4. **`mysql::server::config`** (`migration-dependencies/mysql/manifests/server/config.pp`)
   - Creates the include directory when `includedir` is non-empty.
   - Uses `$facts['os']['family']` for Debian-specific directory handling.
   - Manages `file['mysql-config-file']` when `manage_config_file` is true.
   - Renders `mysql/my.cnf.epp` once per managed host.
   - Renders the effective `mysqld` and `mysqld_safe` option dictionaries.
   - Preserves the reported host overrides:
     - `db-02.srv.local`: `server_id = '2'`, `innodb_flush_log_at_trx_commit = '2'`
     - `db-03.srv.local`: `server_id = '3'`, `innodb_flush_log_at_trx_commit = '2'`
   - Exact EPP variable names and literal non-overridden Hiera values require source review.

5. **`mysql::server::install`** (`migration-dependencies/mysql/manifests/server/install.pp`)
   - Runs when `package_manage` is true.
   - Declares logical Puppet package resource `package['mysql-server']` with `ensure: present`.
   - The distribution package name is provider-dependent and must be verified before implementation.

6. **`mysql::server::managed_dirs`** (`migration-dependencies/mysql/manifests/server/managed_dirs.pp`)
   - Runs when `managed_dirs` is true.
   - Creates dependency-module-managed MySQL directories.
   - Manages the binary-log directory when `logbin` is true.
   - Exact paths and modes require dependency-module source verification.

7. **`mysql::server::installdb`** (`migration-dependencies/mysql/manifests/server/installdb.pp`)
   - Runs when `package_manage` is true.
   - Manages `file[$log_dir]`.
   - Manages `mysql_datadir[$datadir]`.
   - Exact resolved log and data directory values require source and Hiera verification.

8. **`mysql::server::service`** (`migration-dependencies/mysql/manifests/server/service.pp`)
   - Runs when `real_service_manage` is true.
   - Examines `override_options['mysqld']['user']` for service-user handling.
   - Manages `service['mysqld']` with `ensure: running`.
   - Orders `file['mysql-config-file']` before `service['mysqld']`.
   - The supplied analysis confirms a conditional restart branch but does not establish whether the implementation restarts or reloads the service. Verify provider behavior before migration.

9. **`mysql::server::root_password`** (`migration-dependencies/mysql/manifests/server/root_password.pp`)
   - Handles Sensitive and non-Sensitive root passwords.
   - Skips initialization or rotation when the password is `'UNSET'`.
   - Declares `exec['remove install pass']`; its exact command and semantics require source verification.
   - Creates `mysql_user['root@localhost']` when `create_root_user` and `root_password_set` are true.
   - Creates `${facts['root_home']}/.my.cnf` from `mysql/my.cnf.pass.epp` when `create_root_my_cnf` and `root_password_set` are true.
   - Manages `${facts['root_home']}/.mylogin.cnf` when `create_root_login_file` and `root_password_set` are true.
   - Orders `mysql_user['root@localhost']` before `${facts['root_home']}/.my.cnf`.
   - Migrates `root_password` and, when used, `old_root_password` to Ansible Vault.

10. **`mysql::server::providers`** (`migration-dependencies/mysql/manifests/server/providers.pp`)
    - Uses `create_resources[mysql_user]` for the effective user hash.
    - Uses `create_resources[mysql_grant]` for the effective grant hash.
    - Uses `create_resources[mysql_database]` for the effective database hash.
    - No concrete provider-hash entries were supplied; do not invent loop items. Enumerate actual entries after inspecting Hiera.
    - Convert populated entries to explicit `community.mysql` tasks.

11. **`mysql::server::account_security`** (`migration-dependencies/mysql/manifests/server/account_security.pp`)
    - Runs when `remove_default_accounts` is true.
    - Removes or manages:
      - `mysql_user['root@127.0.0.1']`
      - `mysql_user['root@::1']`
      - `mysql_user['@localhost']`
      - `mysql_user['@%']`
      - `mysql_database['test']`
    - When FQDN is not `localhost.localdomain`, also handles:
      - `mysql_user['root@localhost.localdomain']`
      - `mysql_user['@localhost.localdomain']`
    - When an FQDN exists and is not `localhost`, handles:
      - `mysql_user["root@${facts['networking']['fqdn']}"]`
      - `mysql_user["@${facts['networking']['fqdn']}"]`
    - When FQDN and hostname differ, performs additional hostname-specific cleanup. Exact titles are fact-dependent and require runtime verification.
    - Convert removal tasks to `community.mysql.mysql_user` and `community.mysql.mysql_db` with `state: absent`.

12. **`mysql::client`** (`migration-dependencies/mysql/manifests/client.pp`)
    - Includes `mysql::client::install`.
    - Includes `mysql::bindings` when `bindings_enable` is true.
    - Uses anchors `mysql::client::start` and `mysql::client::end`.
    - Orders `mysql::client::start` before `mysql::client::install` and `mysql::client::install` before `mysql::client::end`.

13. **`mysql::client::install`** (`migration-dependencies/mysql/manifests/client/install.pp`)
    - Runs when `mysql::client::package_manage` is true.
    - Declares logical Puppet package resource `package['mysql_client']` with `ensure: present`.
    - The distribution package name is provider-dependent and must be verified.

14. **`mysql::bindings`** (`migration-dependencies/mysql/manifests/bindings.pp`)
    - Runs when `bindings_enable` is true.
    - Uses the OS family fact.
    - Applies Archlinux-specific binding package and path behavior.
    - Applies the default branch for non-Archlinux systems.
    - Includes `mysql::bindings::client_dev` when `client_dev` is true.
    - Includes `mysql::bindings::daemon_dev` when `daemon_dev` is true.

15. **`mysql::bindings::client_dev`** (`migration-dependencies/mysql/manifests/bindings/client_dev.pp`)
    - When `client_dev_package_name` is non-empty, declares logical package resource `package['mysql-client_dev']` with `ensure: present`.
    - Actual package name is OS-dependent and requires verification.

16. **`mysql::bindings::daemon_dev`** (`migration-dependencies/mysql/manifests/bindings/daemon_dev.pp`)
    - When `daemon_dev_package_name` is non-empty, declares logical package resource `package['mysql-daemon_dev']` with `ensure: present`.
    - Actual package name is OS-dependent and requires verification.

17. **`mysql::db[my-demo-db]`** (`migration-dependencies/mysql/manifests/db.pp`)
    - Includes `mysql::client`.
    - Validates `dbname` against `^[^\/\?%*:|\""<>.\s;]{1,64}$`.
    - Uses `$sql` when set.
    - Uses `$mysql_exec_path` when set; otherwise uses the dependency module's default MySQL command path.
    - Manages `mysql_database['my-demo-db']`.
    - Manages `mysql_user['${user}@${host}']`.
    - When `ensure == 'present'`, manages `mysql_grant['${user}@${host}/${table}']`.
    - The supplied analysis does not expose the resolved user, host, table, password, ensure, SQL, executable, or privileges.
    - Verify whether the hyphen in `my-demo-db` is accepted by the exact Puppet validation and provider behavior.

18. **Master-only resources** (`site/profiles/manifests/mysql.pp`)
    - When `is_master` is true, creates `mysql_user['db_admin@192.168.68.%']`.
    - Grants `mysql_grant['db_admin@192.168.68.%/*.*']`.
    - Creates `mysql_user['repl_user@192.168.68.%']`.
    - Grants `mysql_grant['repl_user@192.168.68.%/*.*']`.
    - Ordering is:
      - `db_admin` user
      - `db_admin` grant
      - `repl_user` user
      - `repl_user` grant
    - Passwords and exact privilege lists require source or Hiera verification.

19. **`profiles::mysql::configure_replication`** (`site/profiles/manifests/mysql/configure_replication.pp`)
    - Runs only when `is_master` is false.
    - Deploys `file[$configure_repl_script]`.
    - Executes `exec['configure_replication']`.
    - Uses `$facts['path']` for executable lookup.
    - The script path, content, ownership, mode, and credentials require source review.
    - Ansible should prefer declarative replication modules; if a script remains necessary, use `copy` or `template` plus an idempotence guard.
    - `Class['profiles::mysql']` precedes `Class['profiles::mysql::configure_replication']`.

## Variables

**Variable Flow Summary**: The supplied plan reports one group-level MySQL option dictionary and host-level overrides, but the structured validation does not contain the Hiera files or confirm their hierarchy and merge behavior. Treat the reported recursive/deep merge as a migration hypothesis until the YAML and Hiera configuration are verified. The supplied data identifies 1 reported group-level dictionary, 2 reported host-level override dictionaries, and 2 reported host-level `is_master` values.

### Variable Definitions

#### `data/mysql/default.yaml` — reported group-level MySQL defaults; source verification required

- `profiles::mysql::override_options`: hash
  - `mysqld.bind_address`: literal value and Puppet type unresolved
  - `mysqld.datadir`: literal value and Puppet type unresolved
  - `mysqld.log_error`: literal value and Puppet type unresolved
  - `mysqld.pid_file`: literal value and Puppet type unresolved
  - `mysqld.server_id`: `'1'` (reported string; verify YAML type)
  - `mysqld.innodb_flush_log_at_trx_commit`: `'1'` (reported string; verify YAML type)
  - `mysqld.sync_binlog`: literal value and Puppet type unresolved
  - `mysqld.log_bin`: literal value and Puppet type unresolved
  - `mysqld.relay_log`: literal value and Puppet type unresolved
  - `mysqld_safe.log_error`: literal value and Puppet type unresolved
- `profiles::mysql::is_master`: not supplied; resolve from Puppet defaults or Hiera
- Server, client, root-password, database, account, binding, directory, and replication parameters: not supplied; resolve from Puppet defaults or Hiera

#### `data/nodes/db-02.srv.local.yaml` — reported host-level overrides; source verification required

- `profiles::mysql::is_master`: `false` (reported boolean)
- `profiles::mysql::override_options`: hash
  - `mysqld.server_id`: `'2'` (reported string; verify YAML type)
  - `mysqld.innodb_flush_log_at_trx_commit`: `'2'` (reported string; verify YAML type)
- All other option values are reported as inherited from `data/mysql/default.yaml`; verify the actual merge hierarchy and strategy.

#### `data/nodes/db-03.srv.local.yaml` — reported host-level overrides; source verification required

- `profiles::mysql::is_master`: `false` (reported boolean)
- `profiles::mysql::override_options`: hash
  - `mysqld.server_id`: `'3'` (reported string; verify YAML type)
  - `mysqld.innodb_flush_log_at_trx_commit`: `'2'` (reported string; verify YAML type)
- All other option values are reported as inherited from `data/mysql/default.yaml`; verify the actual merge hierarchy and strategy.

#### Unresolved parameters requiring source review

- `configure_repl_script`
- `manage_config_file`
- `managed_dirs`
- `logbin`
- `package_manage`
- `real_service_manage`
- `restart`
- `includedir`
- `log_dir`
- `datadir`
- `root_password`
- `old_root_password`
- `create_root_user`
- `create_root_my_cnf`
- `create_root_login_file`
- `remove_default_accounts`
- `bindings_enable`
- `client_dev`
- `daemon_dev`
- `user`
- `host`
- `table`
- `password`
- `ensure`
- `privileges`
- `sql`
- `mysql_exec_path`
- Master administrative-account password and privileges
- Replication-account password and privileges
- Any credentials used by the replication script

### Variable Migration Summary

- **Common defaults**: Dependency-module package, service, directory, root-password, client, binding, provider, and account-security defaults; exact values require source verification.
- **OS-specific variables**: Package names, MySQL paths, Debian directory preparation, Archlinux binding behavior, client development package names, and daemon development package names.
- **Environment/group-specific variables**: `profiles::mysql::override_options`, subject to Hiera source verification.
- **Host-specific variables**:
  - `profiles::mysql::is_master`
  - `mysqld.server_id`
  - `mysqld.innodb_flush_log_at_trx_commit`
- **Confirmed credential parameters requiring Vault**:
  - `root_password`
  - `old_root_password` when rotation is enabled
  - `mysql::db.password`
- **Credentials requiring source/Hiera verification before Vault mapping**:
  - `db_admin` password
  - `repl_user` password
  - Replication-script credentials, if present
  - Any provider-hash user passwords

### Cross-Level Overrides

The plan reports the following variable at multiple Hiera levels, but the supplied structured validation does not independently confirm these definitions:

- **`profiles::mysql::override_options`**
  - Reported levels: `data/mysql/default.yaml`, `data/nodes/db-02.srv.local.yaml`, and `data/nodes/db-03.srv.local.yaml`
  - Reported merge strategy: recursive/deep hash merge
  - Reported effective overrides:
    - `mysqld.server_id`: `'1'` default, `'2'` on `db-02.srv.local`, `'3'` on `db-03.srv.local`
    - `mysqld.innodb_flush_log_at_trx_commit`: `'1'` default, `'2'` on both replicas
  - Required action: verify the Hiera hierarchy, lookup options, merge strategy, literal values, and YAML types from source data

### Merge Strategy Notes

- **Hash merge**: Hash values from multiple levels are merged shallowly.
- **Deep merge**: Nested hashes are merged recursively.
- **First merge**: The first value found wins; no merging occurs.
- The reported `profiles::mysql::override_options` behavior is described as deep/recursive but must be confirmed from the actual Hiera configuration.

## Custom Types and Providers

No custom types, providers, facts, or functions are defined in the supplied profile analysis.

The dependency module uses:

- `mysql::server`
- `mysql::db`
- `mysql_user`
- `mysql_grant`
- `mysql_database`
- `mysql_datadir`

Primary Ansible replacements:

- `community.mysql.mysql_user`
- `community.mysql.mysql_db`
- `community.mysql.mysql_query` where direct SQL is unavoidable
- `ansible.builtin.template`
- `ansible.builtin.copy`
- `ansible.builtin.package`
- `ansible.builtin.service`

The exact distribution package names and provider behavior are not verified by the supplied analysis and must be mapped per operating system.

## Dependencies

**External module dependencies**:

- `puppetlabs-mysql` 16.2.0
- `puppetlabs-stdlib` 9.7.0

**System package dependencies**:

- Logical server package: `mysql-server`, provider-dependent distribution name
- Logical client package: `mysql_client`, provider-dependent distribution name
- Logical client development package: `mysql-client_dev`, only when enabled and configured
- Logical daemon development package: `mysql-daemon_dev`, only when enabled and configured
- Python MySQL driver required by `community.mysql`; exact package name requires OS verification

**Service dependencies**:

- MySQL service resource: `mysqld`
- Configuration file before service management
- Root account before `.my.cnf`
- `db_admin` user before its grant
- `db_admin` grant before `repl_user` user
- `repl_user` user before its grant
- `profiles::mysql` before `profiles::mysql::configure_replication` on non-master nodes

## Puppet Facts Used

- `$facts['os']['family']`
  - Selects Debian directory handling and Archlinux binding handling.
- `$::facts['os']['family']`
  - Legacy OS-family reference used by binding subclasses.
- `$facts['root_home']`
  - Determines the root user's `.my.cnf` destination.
- `$facts['puppetversion']`
  - Used by root-password handling for version-specific behavior.
- `$facts['networking']['fqdn']`
  - Controls FQDN-specific account cleanup.
- `$facts['networking']['hostname']`
  - Determines additional cleanup when hostname and FQDN differ.
- `$facts['path']`
  - Supplies the executable search path for `configure_replication`.

Ansible equivalents include:

- `ansible_facts['os_family']`
- `ansible_facts['distribution']`
- An explicit root-home lookup or `ansible_facts['user_dir']`
- `ansible_facts['fqdn']`
- `ansible_facts['hostname']`
- `ansible_env.PATH`

## Template Conversion Notes

### `mysql/my.cnf.epp`

- Render count: 1 per managed MySQL host when `manage_config_file` is true.
- Destination: dependency-module MySQL configuration path; resolve per distribution.
- Reported analysis: 10 EPP variables and 8 logic blocks.
- Exact EPP variable names are not present in the supplied analysis and must be extracted from the template.
- Preserve:
  - Conditional rendering of configured sections
  - Recursive rendering of `mysqld` and `mysqld_safe`
  - OS-specific paths and configuration behavior
  - Effective host overrides
- Expected reported host output:
  - `db-02.srv.local`: `server_id = 2`, `innodb_flush_log_at_trx_commit = 2`
  - `db-03.srv.local`: `server_id = 3`, `innodb_flush_log_at_trx_commit = 2`

### `mysql/my.cnf.pass.epp`

- Render count: 0 or 1 per host.
- Rendered once when root-password setup, `create_root_user`, and `create_root_my_cnf` are enabled.
- Destination: `${facts['root_home']}/.my.cnf`
- Reported analysis: 4 EPP variables and 3 logic blocks.
- Exact EPP variable names are not present in the supplied analysis and must be extracted from the template.
- Preserve conditional authentication and client-section rendering.
- Deploy with root ownership and restrictive permissions.
- Use Vault for the root password.
- Use `no_log: true` for credential-bearing tasks.

### Replication script

- Deployment resource: `file[$configure_repl_script]`
- Execution resource: `exec['configure_replication']`
- Destination, source, ownership, mode, command, and credentials require source review.
- Prefer declarative replication tasks.
- If a script remains necessary, deploy it with `copy` or `template`, use a stable idempotence guard, and protect any credentials with Vault and `no_log: true`.

## Checks for the Migration

**Files to verify**:

- `site/roles/manifests/database.pp`
- `site/profiles/manifests/mysql.pp`
- `site/profiles/manifests/mysql/configure_replication.pp`
- `migration-dependencies/mysql/manifests/server.pp`
- `migration-dependencies/mysql/manifests/server/config.pp`
- `migration-dependencies/mysql/manifests/server/install.pp`
- `migration-dependencies/mysql/manifests/server/managed_dirs.pp`
- `migration-dependencies/mysql/manifests/server/installdb.pp`
- `migration-dependencies/mysql/manifests/server/service.pp`
- `migration-dependencies/mysql/manifests/server/root_password.pp`
- `migration-dependencies/mysql/manifests/server/providers.pp`
- `migration-dependencies/mysql/manifests/server/account_security.pp`
- `migration-dependencies/mysql/manifests/client.pp`
- `migration-dependencies/mysql/manifests/client/install.pp`
- `migration-dependencies/mysql/manifests/bindings.pp`
- `migration-dependencies/mysql/manifests/bindings/client_dev.pp`
- `migration-dependencies/mysql/manifests/bindings/daemon_dev.pp`
- `migration-dependencies/mysql/manifests/db.pp`
- `mysql/my.cnf.epp`
- `mysql/my.cnf.pass.epp`
- `data/mysql/default.yaml`
- `data/nodes/db-02.srv.local.yaml`
- `data/nodes/db-03.srv.local.yaml`
- Relevant encrypted data under `data/secrets/*.eyaml`

**Service endpoints to check**:

- `mysqld` service status and enablement
- `mysqladmin ping`
- Configured MySQL bind address and listening port after resolving `mysqld.bind_address`
- MySQL configuration syntax using the platform-appropriate validation command
- `db-02.srv.local`: effective `server_id = 2`, `innodb_flush_log_at_trx_commit = 2`
- `db-03.srv.local`: effective `server_id = 3`, `innodb_flush_log_at_trx_commit = 2`
- Master default: effective `server_id = 1`, `innodb_flush_log_at_trx_commit = 1`, subject to source verification

**Templates rendered**:

- `mysql/my.cnf.epp`: 1 render per managed MySQL host
- `mysql/my.cnf.pass.epp`: 0 or 1 render per host
- Replication script on `db-02.srv.local`: 0 or 1 deployment
- Replication script on `db-03.srv.local`: 0 or 1 deployment

## Pre-flight checks:

```bash
# Verify service state on the master
systemctl is-enabled mysqld
systemctl is-active mysqld
mysqladmin ping

# Verify service state on db-02.srv.local
ssh db-02.srv.local 'systemctl is-enabled mysqld'
ssh db-02.srv.local 'systemctl is-active mysqld'
ssh db-02.srv.local 'mysqladmin ping'

# Verify service state on db-03.srv.local
ssh db-03.srv.local 'systemctl is-enabled mysqld'
ssh db-03.srv.local 'systemctl is-active mysqld'
ssh db-03.srv.local 'mysqladmin ping'

# Validate the rendered MySQL configuration on the master
# Use the platform-appropriate MySQL configuration test command.

# Validate the rendered MySQL configuration on db-02.srv.local
ssh db-02.srv.local '<platform-appropriate MySQL configuration test command>'

# Validate the rendered MySQL configuration on db-03.srv.local
ssh db-03.srv.local '<platform-appropriate MySQL configuration test command>'

# Verify database and user resources on the master
mysql -e "SHOW DATABASES LIKE 'my-demo-db';"
mysql -e "SELECT User,Host FROM mysql.user WHERE User IN ('db_admin','repl_user');"
mysql -e "SHOW GRANTS FOR 'db_admin'@'192.168.68.%';"
mysql -e "SHOW GRANTS FOR 'repl_user'@'192.168.68.%';"

# Verify the database and configured application user on db-02.srv.local
ssh db-02.srv.local "mysql -e \"SHOW DATABASES LIKE 'my-demo-db';\""
ssh db-02.srv.local "mysql -e \"SELECT User,Host FROM mysql.user;\""

# Verify the database and configured application user on db-03.srv.local
ssh db-03.srv.local "mysql -e \"SHOW DATABASES LIKE 'my-demo-db';\""
ssh db-03.srv.local "mysql -e \"SELECT User,Host FROM mysql.user;\""

# Verify replica-specific settings
ssh db-02.srv.local "mysql -NBe \"SHOW VARIABLES WHERE Variable_name IN ('server_id','innodb_flush_log_at_trx_commit');\""
ssh db-03.srv.local "mysql -NBe \"SHOW VARIABLES WHERE Variable_name IN ('server_id','innodb_flush_log_at_trx_commit');\""

# Verify sensitive files on the master
stat -c '%U %G %a %n' /root/.my.cnf /root/.mylogin.cnf 2>/dev/null || true

# Verify sensitive files on db-02.srv.local
ssh db-02.srv.local "stat -c '%U %G %a %n' /root/.my.cnf /root/.mylogin.cnf 2>/dev/null || true"

# Verify sensitive files on db-03.srv.local
ssh db-03.srv.local "stat -c '%U %G %a %n' /root/.my.cnf /root/.mylogin.cnf 2>/dev/null || true"

# Before implementation, resolve all unresolved Puppet defaults and literal Hiera values.
# Verify the actual Hiera hierarchy and merge strategy for profiles::mysql::override_options.
# Extract the exact EPP variable names from mysql/my.cnf.epp and mysql/my.cnf.pass.epp.
# Confirm distribution package names and Python MySQL driver packages.
# Confirm community.mysql collection availability.
# Confirm Vault coverage for root_password, old_root_password, my-demo-db password,
# db_admin password, repl_user password, provider-hash passwords, and any script credentials.
# Run every credential-bearing Ansible task with no_log: true.
```