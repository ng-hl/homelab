> Ce document contient les livrables issus de la phase de création des templates pour les OS Debian 12 et Rocky Linux 9. L'objectif est de pouvoir disposer de templates de VM afin de créer facilement des clônes complets pour avoir une configuration de base pour l'ensemble de nos VM (utilisateur, clés SSH, installation des paquets de base, ...)

---

# 1. Import des images ISO

Nous avons besoin des ISO suivants pour réaliser la création de nos templates.

| Distribution      | Version     | Adresse de téléchargement de l'ISO
|:-:    |:-:    |:-:
| Debian     | 12.10      | [Download]()
| Rocky Linux     | 9.5      | [Download](https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.5-x86_64-dvd.iso)

---

# 2. Création des templates

Les opérations sont les mêmes pour les deux distributions. Au niveau de Proxmox lors de la création des VM nous allons attribuer les ID 10001 et 10002 (la convention de nommage pour les templates 1000X pour notre homelab), activer le qemu guest agent, créer un disque SCSi de 20Go avec émulation SSD, 1 vCPU, 2048 Mo de RAM avec le balloning activé, une carte réseau positionnée sur le vmbr0 pour avoir un accés par pont au réseau local puis le tag `templates`. Les éléments suivants vont être configurés pour les deux VM créées à partir des ISO précédement récupérés.

| Item      | Debian 12.10     | Rocky Linux 9.5
|:-:    |:-:    |:-:
| Agent QEMU   | Installé (qemu-guest-agent package)     | Installé (qemu-guest-agent package) 
| Hostmane     | debian12-template      | rocky9-template
| Domaine      | homelab                | homelab
| Partitionnement     | LVM (/boot 512Mo, / 10Go, /home 3Go, /var 5Go, SWAP 1Go )      | LVM (/boot 512Mo, / 10Go, /home 3Go, /var 5Go, SWAP 1Go )

# 3. Configuration basique de l'OS

Voici la procédure utilisée pour configurer l'OS qui va servir de template

```bash
# Mise à jour du cache du gestionnaire de paquet et mise à jour des packages
# Debian12
apt update && apt upgrade -y

# Rocky9
sudo yum update -y
```

```bash
# Installation du serveur openssh et sudo
apt install -y openssh-server sudo
```

```bash
# Création de l'utilisateur ansible
sudo useradd --create-home --shell /bin/bash --groups sudo ansible
```

Nous allons créer les paires de clés pour l'utilisateur d'administration `ngobert` ainsi que pour l'utilisateur `ansible`.

```bash
sudo mkdir /root/identites
sudo ssh-keygen -t ed25519 -f /root/identites/id_admin -C "Utilisateur d'administration"
sudo ssh-keygen -t ed25519 -f /root/identites/id_ansible -C "Utilisateur Ansible"
```

> A partit du chapitre 10, "Coffre fort", nous pourrons nous servir de la solution `VaultWarden`pour stocker les clés SSH précédemment générées.

Ces clés doivent être stockées dans un environnement sécurisée. On peut autoriser notre clé privée à se connecter sur les machines en collant le contenu de la clé publique (*.pub) au niveau du fichier `/home/ngobert/.ssh/authorized_keys` et du fichier `/home/ansible/.ssh/authorized_keys`

```bash
# Configuration du réseau (adresse IP standard non utilisable dans ce contexte)
# Debian12
sudo vim /etc/network/interfaces
[...]
auto eth0
iface eth0 inet static
    address 192.168.30.1/24 # Pour Debian12 et .2 pour RockyLinux9
    gateway 192.168.30.254

# Rocky9
nmtui
```