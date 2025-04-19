> Ce document contient les livrables issus de la mise ne place des roles et playbooks Ansible nécessaire à la configuration des nouvelles VM. L'objectif est de pouvoir disposer d'un ensemble de vm avec une configuration cohérente post-deploiement.

---

# 1. Conversion des tâches de configuration manuelle

> Pour le développement de ces roles et les essais, nous allons déployer une VM à partir du template `debian12-template`. Pour le moment, nous gérerons les rollback des applications du playbook via les snapshot intégrés sur Proxmox VE. Notre VM de test aura les caractéristiques suivantes

| Hostname | IPv4 | Sous réseau |
| :-: | :-: | :-: |
| test-core | 192.168.200.10 | core |

> Autre élément important, nous réservons l'IP `192.168.100.1` pour la VM temporaire `test-core`

Avant la mise en place d'Ansible, nous réalisions un ensemble d'opération pour configurer les VM fraîchement créée sur notre Proxmox VE. Nous allons traduire cela en playbook Ansibe.

Modification de la configuration réseau avec le fichier `/etc/network/interfaces`

- [x] Configuration IPv4 de l'interface réseau
- [ ] Gestion de la mise à jour du DNS
- [ ] Désactivation de l'IPv6
- [ ] Configuration du hostname
- [ ] Modification de /etc/hosts avec le bon hostname
- [ ] Configuration du résolveur DNS
- [ ] Installation des paquets de "base" (ajout)
- [ ] Modification du motd (ajout)

Tout d'abord, nous créons l'architecture pour l'ensemble des roles que nous allons créer

```bash
ansible-galaxy init roles/network_config
ansible-galaxy init roles/ipv6_disable
ansible-galaxy init roles/hostname_config
ansible-galaxy init roles/local_dns_config
ansible-galaxy init roles/dns_config
```

Contenu du fichier `roles/network_config/templates/etc_network_interfaces.j2`

```j2
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

{% set network_prefix = ip.split('.')[0:3] | join('.') %}
{% set last_octet = ip.split('.')[3] %}
{% if network_prefix == '192.168.100' %}
  {% set type = 'core' %}
  {% set gateway = '192.168.100.254' %}
{% elif network_prefix == '192.168.200' %}
  {% set type = 'vms' %}
  {% set gateway = '192.168.200.254' %}
{% else %}
  {% set type = 'unknown' %}
  {% set gateway = '0.0.0.0' %}
{% endif %}

# LAN {{ type }}
auto ens19
iface ens19 inet static
    address {{ ip }}/24
    gateway {{ gateway }}
```

Contenu du fichier `roles/network_config/handlers/main.yml`

```yaml
#SPDX-License-Identifier: MIT-0
---
# handlers file for roles/network_config

- name: Restart du daemon networking
  ansible.builtin.systemd_service:
    name: networking.service
    state: restarted
```

Contenu du fichier `roles/network_config/tasks/main.yml`

```yaml
#SPDX-License-Identifier: MIT-0
---
# tasks file for roles/motd
# Rôle permettant la modification de la configuration IPv4

- name: Déploiement de la configuration IPv4
  ansible.builtin.template:
    src: etc_network_interfaces.j2
    dest: /etc/network/interfaces
    mode: '0644'
    owner: root
    group: root
  notify: Restart du daemon networking
```