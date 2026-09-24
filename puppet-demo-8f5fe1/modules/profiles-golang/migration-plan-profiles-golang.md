---
source-path: site/profiles/manifests/golang.pp
---

# Migration Plan: profiles-golang

**TLDR**: The `profiles::golang` branch installs the latest available Go release from `https://go.dev/dl` into `/usr/local/go`, extracts the archive without its top-level directory, and creates `/usr/local/bin/go` and `/usr/local/bin/gofmt` symlinks. The branch is included by `roles::web_server`, but this migration covers only the Golang branch; Nginx, Consul, inherited base resources, unrelated templates, and unrelated PuppetDB collectors are out of scope. No Go service, credentials, Hiera overrides, or PuppetDB dependency is used by this branch.

## Service Type and Instances

**Service Type**: System toolchain/runtime installation

**Execution Context**:

- **`roles::web_server`** (`site/roles/manifests/web_server.pp`)
  - Includes `profiles::golang` alongside `profiles::nginx` and `profiles::consul`.
  - Only the `profiles::golang` branch is included in this migration.
  - Nginx, Consul, inherited base resources, their templates, and their PuppetDB usage are outside this migration scope.

**Configured Instances**:

- **Go installation**:
  - Location/Path: `/usr/local/go`
  - Download source: dynamically generated from `https://go.dev/dl`
  - Version: latest stable version returned by `https://go.dev/dl/?mode=json`
  - Archive format: `.tar.gz`
  - Ownership: Puppet execution user and group from `facts['identity']`; detailed manifest confirmation is required before implementation
  - Mode: `0755`
  - Extraction: archive contents are extracted with the top-level directory removed

- **Go command symlink**:
  - Location/Path: `/usr/local/bin/go`
  - Port/Socket: None
  - Target: `/usr/local/go/bin/go`
  - Required after: `Golang::From_tarball[/usr/local/go]`

- **Go formatter symlink**:
  - Location/Path: `/usr/local/bin/gofmt`
  - Port/Socket: None
  - Target: `/usr/local/go/bin/gofmt`
  - Required after: `Golang::From_tarball[/usr/local/go]`

## File Structure

**MANDATORY: Preserve this section from the original plan.**

```text
### Manifests

- `site/profiles/manifests/golang.pp`
- `migration-dependencies/golang/manifests/init.pp`
- `migration-dependencies/golang/manifests/installation.pp`
- `migration-dependencies/golang/manifests/from_tarball.pp`
- `migration-dependencies/golang/manifests/linked_binaries.pp`
- `migration-dependencies/archive/manifests/init.pp`

### Supporting dependency components

- `migration-dependencies/archive/manifests/params.pp`
- `migration-dependencies/archive/manifests/download.pp`
- `migration-dependencies/archive/manifests/go.pp`

No templates are rendered by this execution path.
```

## Module Explanation

The effective execution order is:

1. `roles::web_server` includes `profiles::golang`.
2. `profiles::golang` includes `golang`.
3. `golang` creates `golang::installation '/usr/local/go'`.
4. `golang::installation` creates `golang::from_tarball '/usr/local/go'`.
5. `golang::from_tarball` manages the installation directory, ownership remediation, and archive extraction.
6. `golang::linked_binaries '/usr/local/go'` creates the two command symlinks.

The Nginx and Consul branches included by `roles::web_server` are not part of this execution flow.

1. **`roles::web_server`** (`site/roles/manifests/web_server.pp`):
   - Includes `profiles::golang`, `profiles::nginx`, and `profiles::consul`.
   - Only the `profiles::golang` branch is migrated.
   - Nginx, Consul, and inherited base resources are explicitly out of scope.

2. **`profiles::golang`** (`site/profiles/manifests/golang.pp`):
   - Includes `golang`.
   - Declares no profile parameters.
   - Defines no explicit ordering or notification relationship.
   - Evaluates the `golang` class using dependency-module defaults.

3. **`golang`** (`migration-dependencies/golang/manifests/init.pp`):
   - Resolves `ensure` to `present`.
   - Resolves `version` to `undef`.
   - Uses `link_binaries: ['go', 'gofmt']`.
   - Uses `source_prefix: https://go.dev/dl`.
   - Leaves `source` undefined, so the generated source URL path is used.
   - Derives `os` from `facts['kernel']`:
     - `Linux` → `linux`
     - `Darwin` → `darwin`
     - Other values remain unchanged.
   - Derives `arch` from `facts['os']['hardware']`:
     - `undef` → `amd64`
     - `aarch64` → `arm64`
     - `armv7l` → `armv6l`
     - `i686` → `386`
     - `x86_64` → `amd64`
     - Other values remain unchanged.
   - Does not execute the fixed-version branch because `version` is `undef`.
   - Executes the generated-source branch because `source` is `undef`.
   - Creates `golang::installation '/usr/local/go'`.
   - Creates `golang::linked_binaries '/usr/local/go'`.

4. **`golang::installation '/usr/local/go'`** (`migration-dependencies/golang/manifests/installation.pp`):
   - Resolves `ensure` to `present`.
   - Uses `go_dir: /usr/local/go`.
   - Uses `source_prefix: https://go.dev/dl`.
   - Inherits fact-derived `os` and `arch`.
   - Uses `owner: facts['identity']['user']` and `group: facts['identity']['group']`; these identity fact references require confirmation in the detailed manifest analysis.
   - Uses `mode: 0755`.
   - Uses `state_file: /usr/local/.go.source_url`.
   - Resolves the version by calling `golang::latest_version('https://go.dev/dl/?mode=json')`.
   - Generates the archive URL:
     - `https://go.dev/dl/go<VERSION>.<OS>-<ARCH>.tar.gz`
   - On Linux x86_64, the URL shape is:
     - `https://go.dev/dl/go<VERSION>.linux-amd64.tar.gz`
   - Creates `golang::from_tarball '/usr/local/go'` with `ensure: any_version`.
   - The `present` value intentionally maps to `any_version` at this layer.
   - The state file is not managed in the effective `any_version` path.

5. **`golang::from_tarball '/usr/local/go'`** (`migration-dependencies/golang/manifests/from_tarball.pp`):
   - Uses the generated Go archive URL as `source`.
   - Uses `ensure: any_version`.
   - Uses `go_dir: /usr/local/go`.
   - Uses the Puppet execution identity for `owner` and `group`, subject to identity-fact confirmation.
   - Uses `mode: 0755`.
   - Uses `state_file: /usr/local/.go.source_url`.
   - Encodes `/usr/local/go` as `_usr_local_go`.
   - Uses archive path `/tmp/puppet-golang_usr_local_go.tar.gz`.
   - Does not create the state-file resource because `ensure` is `any_version`.
   - Does not create the refresh exec because `ensure` is not `present`.
   - Creates `exec['dp/golang check ownership of /usr/local/go']`:
     - Command: `rm -rf /usr/local/go`
     - Environment includes `GO_DIR`, `OWNER`, and `GROUP`.
     - Checks whether files beneath `/usr/local/go` have an unexpected owner or group.
     - Runs before `File[/usr/local/go]`.
     - Notifies the archive resource if it executes.
   - Creates `File[/usr/local/go]`:
     - Ensure: `directory`
     - Force: `true`
     - Owner and group: Puppet execution identity
     - Mode: `0755`
   - Includes `archive`.
   - Creates `Archive[/tmp/puppet-golang_usr_local_go.tar.gz]`:
     - Ensure: `present`
     - Extract: `true`
     - Extract path: `/usr/local/go`
     - Extract flags: `--strip-components 1 --no-same-owner --no-same-permissions -xf`
     - User and group: Puppet execution identity
     - Source: generated Go archive URL
     - Creates: `/usr/local/go/bin`
     - Cleanup: `true`
     - Requires: `File[/usr/local/go]`
   - Extraction removes the archive’s top-level directory.
   - Archive ownership and permissions do not override the requested installation ownership and mode.
   - Existing `/usr/local/go/bin` makes extraction idempotent when ownership is correct.
   - Incorrect ownership causes the complete Go installation directory to be removed and reinstalled.
   - No service is restarted or notified.

6. **`archive`** (`migration-dependencies/archive/manifests/init.pp`):
   - Includes `archive::params`.
   - The Linux path does not execute the Windows-specific `package '7zip'` branch.
   - AWS CLI and `gsutil` installation branches do not execute unless separately configured.
   - The archive collection loop has no additional entries from this profile.
   - The effective resource is `Archive[/tmp/puppet-golang_usr_local_go.tar.gz]`.

7. **`golang::linked_binaries '/usr/local/go'`** (`migration-dependencies/golang/manifests/linked_binaries.pp`):
   - Uses `ensure: present`.
   - Uses `go_dir: /usr/local/go`.
   - Uses `into_bin: /usr/local/bin`.
   - Uses `binaries: ['go', 'gofmt']`.
   - `$binaries.each` runs exactly two iterations:
     - **`go`**:
       - Creates `File[/usr/local/bin/go]`.
       - Ensures a symlink to `/usr/local/go/bin/go`.
       - Requires `Golang::From_tarball[/usr/local/go]`.
     - **`gofmt`**:
       - Creates `File[/usr/local/bin/gofmt]`.
       - Ensures a symlink to `/usr/local/go/bin/gofmt`.
       - Requires `Golang::From_tarball[/usr/local/go]`.

## Variables

**Variable Flow Summary**: Seven effective Golang class settings are defined by module defaults; no Golang-specific Hiera variables or Hiera data files were supplied. OS, architecture, and installation identity values are derived from Puppet facts. There are no Hiera merge operations or overrides.

### Variable Definitions

**Hiera data files supplied**: None.

No `common.yaml`, OS-specific, environment-specific, host-specific, or encrypted Hiera values were supplied for this module.

**`profiles::golang`** → Migration note: Profile entry point; no configurable parameters.

- No variables.
- Includes `golang`.

**`golang` module defaults** → Migration note: Module-level defaults apply because no Hiera overrides were supplied.

- `ensure`: `present` (type: `Golang::Ensure`)
- `version`: `undef` (type: optional Go version)
- `link_binaries`: `['go', 'gofmt']` (type: array of strings)
- `source_prefix`: `https://go.dev/dl` (type: URL string)
- `source`: `undef` (type: optional URL string)
- `os`: fact-derived (type: non-empty string)
- `arch`: fact-derived (type: non-empty string)

**`golang::installation '/usr/local/go'`** → Migration note: Defined-type parameters inherit module defaults and derive ownership and platform values from facts.

- `ensure`: `present`
- `go_dir`: `/usr/local/go`
- `source_prefix`: `https://go.dev/dl`
- `os`: fact-derived
- `arch`: fact-derived
- `owner`: `facts['identity']['user']`; confirm this identity fact in the detailed manifest analysis
- `group`: `facts['identity']['group']`; confirm this identity fact in the detailed manifest analysis
- `mode`: `0755`
- `state_file`: `/usr/local/.go.source_url`

**`golang::from_tarball '/usr/local/go'`** → Migration note: Installation-level `present` is converted to `any_version`.

- `ensure`: `any_version`
- `go_dir`: `/usr/local/go`
- `source`: dynamically generated Go download URL
- `owner`: `facts['identity']['user']`; confirmation required
- `group`: `facts['identity']['group']`; confirmation required
- `mode`: `0755`
- `state_file`: `/usr/local/.go.source_url`

**`golang::linked_binaries '/usr/local/go'`** → Migration note: Creates the two fixed command links.

- `ensure`: `present`
- `into_bin`: `/usr/local/bin`
- `go_dir`: `/usr/local/go`
- `binaries`: `['go', 'gofmt']`

### Puppet-to-Ansible Variable Mapping

- `golang::ensure` → `golang_ensure`, default `present`
- `golang::version` → `golang_version`, default unset; when unset, query the Go download API
- `golang::link_binaries` → `golang_link_binaries`, default `['go', 'gofmt']`
- `golang::source_prefix` → `golang_source_prefix`, default `https://go.dev/dl`
- `golang::source` → `golang_source`, default unset
- `golang::os` → `golang_os`, derived from `ansible_facts.kernel`
- `golang::arch` → `golang_arch`, derived from `ansible_facts.architecture`
- `golang::installation::go_dir` → `golang_install_dir`, default `/usr/local/go`
- `golang::installation::owner` → `golang_install_owner`; explicitly define this in Ansible after confirming Puppet identity behavior
- `golang::installation::group` → `golang_install_group`; explicitly define this in Ansible after confirmation
- `golang::installation::mode` → `golang_install_mode`, default `0755`
- `golang::installation::state_file` → `golang_state_file`, default `/usr/local/.go.source_url`
- Generated source URL → `golang_archive_url`
- `golang::linked_binaries::into_bin` → `golang_binary_dir`, default `/usr/local/bin`

### Variable Migration Summary

- **Common defaults**: 7 Golang class settings from module defaults
- **OS-specific variables**: 1 derived value, `os`
- **Architecture-specific variables**: 1 derived value, `arch`
- **Environment-specific variables**: 0
- **Host-specific variables**: 0
- **Encrypted variables**: 0
- **Hiera data files**: 0 supplied
- **Ansible variables requiring explicit confirmation**: installation owner and group

### Cross-Level Overrides

- No Golang variables were present in the supplied Hiera analysis.
- No variables are defined at multiple Hiera levels.
- No merge strategy is required.
- Unrelated Consul, MySQL, Nagios, GitLab, application, Nginx, and PuppetDB values do not affect this Golang branch.

### Merge Strategy Notes

- No `hash` merge variables are used.
- No `deep` merge variables are used.
- No `first`-level Hiera overrides are used.
- Ansible should use explicit role defaults with inventory or host overrides only if deployment-specific behavior is required.

## Custom Types and Providers

No custom Puppet resource types or providers are defined.

The following Puppet defined types are present and must be represented as Ansible task blocks, role components, or reusable task files:

- `golang::installation` (`migration-dependencies/golang/manifests/installation.pp`)
  - Resolves the Go version and delegates installation to `golang::from_tarball`.
- `golang::from_tarball` (`migration-dependencies/golang/manifests/from_tarball.pp`)
  - Manages ownership remediation, installation-directory creation, and archive extraction.
- `golang::linked_binaries` (`migration-dependencies/golang/manifests/linked_binaries.pp`)
  - Iterates over `go` and `gofmt` to create symlinks.
- `archive` (`migration-dependencies/archive/manifests/init.pp`)
  - Provides the archive download and extraction resource used by the Go installation.

The module also uses helper logic for:

- **`golang::latest_version`**
  - Calls `https://go.dev/dl/?mode=json`.
  - Parses the API response to identify the latest stable Go release.
  - Supplies the version to the archive URL generator.
  - Ansible should replace this with an HTTP retrieval task followed by JSON parsing and a validation task. API access or response parsing failures must fail the deployment rather than silently selecting an invalid version.
- Go ensure-value validation.
- State-file path calculation.
- Platform and architecture mapping.

No custom Puppet facts or custom providers are used by this branch.

## Dependencies

**External module dependencies**:

- `dp-golang`; exact version is not supported by the supplied analysis and must be obtained from Puppetfile or module metadata before migration.
- `puppet-archive`; exact version is not supported by the supplied analysis and must be obtained from Puppetfile or module metadata before migration.
- `puppetlabs-stdlib`; exact version is not supported by the supplied analysis and must be obtained from Puppetfile or module metadata before migration.

**System package dependencies**:

- No operating-system package is installed for Go.
- The Windows-only `7zip` branch is not used on the expected Linux path.
- Standard system utilities capable of downloading and extracting `.tar.gz` archives are required.

**Service dependencies**:

- None.
- No Go service is enabled, started, stopped, or restarted.

**Ansible implementation dependencies**:

- `ansible.builtin.uri` or equivalent API client for latest-version lookup
- `ansible.builtin.get_url` or equivalent download mechanism
- `ansible.builtin.unarchive`
- `ansible.builtin.file`
- `ansible.builtin.command` or `ansible.builtin.shell` for ownership remediation if exact Puppet behavior is retained
- `ansible_facts.kernel`
- `ansible_facts.architecture`

## Puppet Facts Used

- `facts['kernel']`
  - Determines the archive operating-system identifier.
  - `Linux` maps to `linux`.
  - `Darwin` maps to `darwin`.

- `facts['os']['hardware']`
  - Determines the Go archive architecture.
  - `aarch64` maps to `arm64`.
  - `armv7l` maps to `armv6l`.
  - `i686` maps to `386`.
  - `x86_64` maps to `amd64`.
  - Undefined values default to `amd64`.

- `facts['identity']['user']`
  - Reported by the manifest analysis as the installation owner and archive extraction user.
  - This fact is not present in the supplied structured execution summary and must be confirmed before implementation.

- `facts['identity']['group']`
  - Reported by the manifest analysis as the installation group and archive extraction group.
  - This fact is not present in the supplied structured execution summary and must be confirmed before implementation.

### Ansible Fact Mapping

- `facts['kernel']` → `ansible_facts.kernel`
- `facts['os']['hardware']` → `ansible_facts.architecture`
- `facts['identity']['user']` → explicit `golang_install_owner`; do not assume it equals the Ansible connection user without confirmation
- `facts['identity']['group']` → explicit `golang_install_group`; do not infer it without confirmation

## PuppetDB Dependencies

No PuppetDB dependencies are used by `profiles::golang`.

- No exported resources (`@@`) are used.
- No virtual resources (`@`) are used.
- No resource collectors (`<<| |>>`) are used.
- No `puppetdb_query()` calls are used.
- No host identity data is read from PuppetDB.

The repository-wide execution tree contains unrelated PuppetDB collectors in:

- `migration-dependencies/nginx/manifests/service.pp`
- `migration-dependencies/nginx/manifests/resource/upstream.pp`

Those collectors belong to the Nginx branch included by `roles::web_server` and are outside this Golang migration.

## Credentials

No credentials are consumed by `profiles::golang`.

- The Go download URL is public.
- No username, password, token, key, or encrypted variable is supplied.
- The generic archive dependency may support authenticated downloads in other contexts, but no authenticated archive parameters are configured for this branch.

## Checks for the Migration

**Files to verify**:

- `site/profiles/manifests/golang.pp`
- `migration-dependencies/golang/manifests/init.pp`
- `migration-dependencies/golang/manifests/installation.pp`
- `migration-dependencies/golang/manifests/from_tarball.pp`
- `migration-dependencies/golang/manifests/linked_binaries.pp`
- `migration-dependencies/archive/manifests/init.pp`
- `migration-dependencies/archive/manifests/params.pp`
- `migration-dependencies/archive/manifests/download.pp`
- `migration-dependencies/archive/manifests/go.pp`
- `/usr/local/go`
- `/usr/local/go/bin/go`
- `/usr/local/go/bin/gofmt`
- `/usr/local/bin/go`
- `/usr/local/bin/gofmt`
- `/usr/local/.go.source_url` only if state-file compatibility is intentionally implemented

**Service endpoints to check**:

- None.

**Templates rendered**:

- `profiles::golang`: 0 templates rendered.
- Nginx templates such as `nginx/conf.d/geo.erb` and `nginx/conf.d/map.epp` belong to the unrelated `profiles::nginx` branch and are outside this migration.

**Pre-flight checks**:

- **Go installation `/usr/local/go`**:
  - Verify the host kernel and architecture map to a supported Go archive identifier.
  - Verify outbound HTTPS access to `https://go.dev/dl`.
  - Verify `/usr/local` is writable by the privileged Ansible execution user.
  - Verify the selected installation owner and group exist.
  - Confirm whether an existing `/usr/local/go` installation may be removed if ownership is incorrect.
  - Confirm the Puppet identity fact behavior before setting Ansible ownership variables.

- **Go command symlink `/usr/local/bin/go`**:
  - Verify `/usr/local/bin` exists or can be created.
  - Verify no incompatible file must be preserved at `/usr/local/bin/go`.
  - Verify the target path `/usr/local/go/bin/go` will exist after extraction.

- **Go formatter symlink `/usr/local/bin/gofmt`**:
  - Verify `/usr/local/bin` exists or can be created.
  - Verify no incompatible file must be preserved at `/usr/local/bin/gofmt`.
  - Verify the target path `/usr/local/go/bin/gofmt` will exist after extraction.

**Post-deployment checks**:

```bash
/usr/local/go/bin/go version
/usr/local/bin/go version
/usr/local/bin/gofmt
readlink -f /usr/local/bin/go
readlink -f /usr/local/bin/gofmt
stat -c '%U:%G %a %n' /usr/local/go /usr/local/bin/go /usr/local/bin/gofmt
```

Expected symlink targets:

- `/usr/local/bin/go` → `/usr/local/go/bin/go`
- `/usr/local/bin/gofmt` → `/usr/local/go/bin/gofmt`

**Ansible idempotency checks**:

- A second run must not redownload or re-extract the archive when `/usr/local/go/bin` exists and ownership is correct.
- If any file beneath `/usr/local/go` has the wrong owner or group, the migration must reproduce Puppet behavior by removing and reinstalling the complete Go directory.
- `/usr/local/bin/go` must remain a symlink to `/usr/local/go/bin/go`.
- `/usr/local/bin/gofmt` must remain a symlink to `/usr/local/go/bin/gofmt`.
- Latest-version API failures or invalid API responses must fail clearly and must not produce an invalid archive URL.
