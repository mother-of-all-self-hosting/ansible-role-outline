<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Alejandro AR
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 Thomas Miceli
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Outline

This is an [Ansible](https://www.ansible.com/) role which installs [Outline](https://www.getoutline.com/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Outline is an open-source knowledge base for growing teams.

See the project's [documentation](https://docs.getoutline.com/s/guide) to learn what Outline does and why it might be useful to you.

## Prerequisites

To run a Outline instance it is necessary to prepare a [Postgres](https://www.postgresql.org/) database server and [Redis](https://redis.io/) database for managing cache data.

If you are looking for Ansible roles for them, you can check out [ansible-role-postgres](https://github.com/mother-of-all-self-hosting/ansible-role-postgres) and [ansible-role-redis](https://github.com/mother-of-all-self-hosting/ansible-role-redis), both of which are maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team. The role for [Valkey](https://valkey.io/) ([ansible-role-valkey](https://github.com/mother-of-all-self-hosting/ansible-role-valkey)) is available as well.

## Adjusting the playbook configuration

To enable Outline with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# outline                                                              #
#                                                                      #
########################################################################

outline_enabled: true

########################################################################
#                                                                      #
# /outline                                                             #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Outline you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
outline_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting Outline under a subpath (by configuring the `outline_path_prefix` variable) does not seem to be possible due to Outline's technical limitations.

### Set random 32-byte hex digits for secret key

You also need to set random **32-byte hex digits** for the secret key. To do so, add the following configuration to your `vars.yml` file. The value can be generated with `openssl rand -hex 32` or in another way.

```yaml
outline_environment_variable_secret_key: YOUR_SECRET_KEY_HERE
```

### Configure authentication methods

For Outline to work, at least one [authentication method](https://docs.getoutline.com/s/hosting/doc/authentication-7ViKRmRY5o) must be enabled. Refer to [`defaults/main.yml`](../defaults/main.yml) for the `outline_environment_variable_*` variables to be used for authentication.

If SMTP settings are defined (see the `outline_environment_variable_smtp_*` variables in `defaults/main.yml`), the [Email magic link](https://docs.getoutline.com/s/hosting/doc/email-magic-link-N2CPh5tmTS) authentication method will be enabled.

>[!NOTE]
> Even with SMTP settings being defined, we haven't been able to get Outline to successfully send emails yet, hitting issues similar to [this one](https://github.com/outline/outline/discussions/2605).

### Configuring database

#### Set variables for the database server

To have the Outline instance connect to your Postgres server, add the following configuration to your `vars.yml` file.

```yaml
outline_database_username: YOUR_POSTGRES_SERVER_USERNAME_HERE
outline_database_password: YOUR_POSTGRES_SERVER_PASSWORD_HERE
outline_database_name: YOUR_POSTGRES_SERVER_DATABASE_NAME_HERE
```

Make sure to replace the placeholders with your own values.

#### Configuring connection to the database server (optional)

By default the role is configured to establish connection with the Postgres server via the Unix socket. You can mount the Unix socket by adding the following configuration to your `vars.yml` file:

```yaml
# Specify the path to the Postgres Unix socket path on the host (bind-mount source)
outline_database_socket_path_host: ""
```

Setting it enables to connect to the Postgres server via Unix socket mounted in the container at `/run-postgres/.s.PGSQL.5432`.

If TCP connection is preferred, connection via the Unix socket can be disabled by adding the following configuration to your `vars.yml` file:

```yaml
# Disable the connection to Postgres server via a Unix socket
outline_database_socket_enabled: false

outline_database_hostname: YOUR_POSTGRES_SERVER_HOSTNAME_HERE
outline_database_port: 5432
```

### Configuring a Redis database (optional)

You can optionally enable a [Redis](https://redis.io/) database for the Outline instance. [Valkey](https://valkey.io/) can also be used instead.

To enable the Redis database for Outline, add the following configuration to your `vars.yml` file. Note that the role is by default configured to establish connection with the Redis database via the Unix socket.

```yaml
# Specify the path to the Redis Unix socket path on the host (bind-mount source)
outline_redis_socket_path_host: ""

outline_redis_database: 0
```

If TCP connection is preferred, connection via the Unix socket can be disabled by adding the following configuration to your `vars.yml` file:

```yaml
# Disable the connection to Redis via a Unix socket
outline_redis_socket_enabled: false

outline_redis_hostname: YOUR_REDIS_SERVER_HOSTNAME_HERE
```

Make sure to replace `YOUR_REDIS_SERVER_HOSTNAME_HERE` with your own value.

If you are looking for an Ansible role for Redis, you can check out [ansible-role-redis](https://github.com/mother-of-all-self-hosting/ansible-role-redis) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team. The role for Valkey ([ansible-role-valkey](https://github.com/mother-of-all-self-hosting/ansible-role-valkey)) is available as well.

### Configuring file storage

Outline supports multiple [file storage](https://docs.getoutline.com/s/hosting/doc/file-storage-N4M0T6Ypu7) mechanisms.

The default configuration stores files locally in a `data` directory, but you can also stores files on AWS S3 (or [compatible S3 alternative](https://docs.getoutline.com/s/hosting/doc/file-storage-N4M0T6Ypu7#h-s3-compatible-services)).

To enable S3 storage, add the following to your `vars.yml` configuration:

```yml
outline_environment_variable_file_storage: s3

outline_environment_variable_aws_access_key_id: ''
outline_environment_variable_aws_secret_access_key: ''
outline_environment_variable_aws_region: eu-central-1 # example
outline_environment_variable_aws_s3_upload_bucket_url: https://OUTLINE_ASSETS_BUCKET_NAME.s3.eu-central-1.amazonaws.com
outline_environment_variable_aws_s3_upload_bucket_name: OUTLINE_ASSETS_BUCKET_NAME
outline_environment_variable_aws_s3_force_path_style: false
```

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `outline_environment_variables_additional_variables` variable

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Outline becomes available at the specified hostname like `https://example.com`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu outline` (or how you/your playbook named the service, e.g. `mash-outline`).

#### Increase logging verbosity

If you want to increase the verbosity, add the following configuration to your `vars.yml` file:

```yaml
outline_environment_variable_log_level: DEBUG
```
