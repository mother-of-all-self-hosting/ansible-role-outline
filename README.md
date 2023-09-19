# Outline Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Outline](https://www.getoutline.com/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [defaults/main.yml](defaults/main.yml) for the full list of supported options.

This role is integrated into the [MASH playbook](https://github.com/mother-of-all-self-hosting/mash-playbook) where [Outline is a supported service](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/services/outline.md).
