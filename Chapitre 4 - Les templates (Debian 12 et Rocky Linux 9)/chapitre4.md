> Ce document contient les livrables issues de la phase de création des templates pour les OS Debian 12 et Rocky Linux 9. L'objectif est de pouvoir disposer de templates de VM afin de créer facilement des clône complet pour avoir une configuration de base pour l'ensemble de nos VM (utilisateur, clés SSH, installation d'openssh-server, ...)

---

# 1. Import des images ISO

Nous avons besoin des ISO suivantes pour réaliser la création de nos templates.

| Distribution      | Version     | Adresse de téléchargement de l'ISO
|:-:    |:-:    |:-:
| Debian     | 12.10      | [Download]()
| Rocky Linux     | 9.5      | [Download](https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.5-x86_64-dvd.iso)

---

# 2. Création des templates

Les opérations sont les mêmes pour les deux distributions. Au niveau de Proxmox lors de la création des VM nous allons attribuer les ID 10001 et 10002 (la convention de nommage pour les templates 1000X pour notre homelab), activer le qemu guest agent, créer un disque SCSi de 20Go avec émulation SSD, 1 vCPU, 2048 Mo de RAM avec le balloning activé, une carte réseau positionné sur le vmbr0 pour avoir un accés par pont au réseau local puis le tag `templates`. Les éléments suivants vont être configurés pour les deux VM créées à partir des ISO précédement récupérées.

| Item      | Debian 12.10     | Rocky Linux 9.5
|:-:    |:-:    |:-:
| Agent QEMU   | Installé (qemu-guest-agent package)     | Installé (qemu-guest-agent package) 
| Hostmane     | debian12-template      | rocky9-template
| Domaine      | homelab                | homelab
| Partitionnement     | LVM (/boot 512Mo, / 10Go, /home 3Go, /var 5Go, SWAP 1Go )      | LVM (/boot 512Mo, / 10Go, /home 3Go, /var 5Go, SWAP 1Go )

