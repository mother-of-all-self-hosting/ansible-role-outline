<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

There are two testing scenarios available.

### `default`

Tests a standard Outline installation against Postgres and Valkey, both reached over Unix sockets, with no sign-in provider configured.

Outline is a single-page application that answers every path it does not recognize — `/healthz` and any typo alike — with the same 200 and the same HTML shell, so a status code proves nothing about it. `/_health` is the one endpoint that cannot lie: it answers with the two bytes `OK`, and it is what the image's own `HEALTHCHECK` probes. Reaching it also means the schema is migrated, since Outline runs its migrations before starting the web service, and an Outline started without a `DATABASE_URL` throws and exits 1 rather than serving an error page.

On top of that the scenario checks the version of the code the container is really executing against the version pinned in `defaults/main.yml`, confirms in the Postgres container that the schema and the migration bookkeeping actually landed there, confirms in the Valkey container that Outline created its job queues, and asks Outline which sign-in providers it offers — which is none, as this scenario configures none.

### `oidc`

Tests the same installation with the generic OpenID Connect sign-in provider configured, and signs in through it.

Outline normally authenticates against an external identity provider — Slack, Google, Microsoft Entra, Discord or a generic OIDC one. This scenario stands a throwaway provider up as a container on the role's own container network (see `oidc/files/oidc-stub.js`) and drives a complete sign-in against it: the redirect to the authorization endpoint, the callback, the token exchange, the userinfo lookup, and the session that comes out the other end.

Two things make that worth doing rather than merely possible. The stub refuses to issue a token unless the client ID and client secret Outline sends match the ones this scenario configured, byte for byte — and the secret deliberately carries dollar signs, so completing a sign-in proves those values survived Ansible, the `env` file this role templates and Docker's `--env-file` parsing intact. And the account that comes back is then read out of the Postgres container, so the round trip closes against the database rather than against Outline's own word for it.

Unlike a reverse-proxy authenticator, Outline never contacts its identity provider while starting up: it accepts the endpoints it is given without checking them, and only calls them when someone signs in. An unreachable provider is therefore not a startup failure but a 500 on the callback, which is why the stub has to be answering by the time the verification runs rather than by the time Outline starts.

What this scenario deliberately does not cover is an identity provider that issues signed ID tokens. Outline's generic OIDC provider, configured with explicit endpoints as this role configures it, reads the account off the userinfo endpoint and only warns when the ID token is not a valid object — so the stub needs no signing key, and nothing here exercises JWKS verification, token signature validation or discovery. Testing those needs a real identity provider.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
molecule test --scenario-name oidc
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
