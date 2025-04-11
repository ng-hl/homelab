> Ce document contient les livrables issues de la phase d'installation et de configuration de Proxmox VE ainsi que des VLAN au sein du homelab. Ces éléments constituent la base (le core) de notre infrastructure.

---

# 1. Installation de Proxmox VE

Proxmox VE (Virtual Environment) est un hyperviseur de type 1 et open source. Cette solution offre de nombreuses fonctionnalités en parfaite cohérence avec les besoins du homelab. Voici un tableau récapitulatif non exhaustif de ces dernières :

| Fonctionnalités      | Description      |
|:-:    |---    |
| Prise en charge complète de la virtualisation avec KVM     | Support de la virtualisation de machines QEMU/KVM     |
| Prise en charge des conteneurs LXC     | Conteneurisation légère et native sous Linux    |
| Interface web     | Interface web qui permet d'interragir avec les éléments de gestion liés à Proxmox VE ainsi que les VM et les containers     |
| Cluster     | Gestion centralisée du cluster dans le cas où plusieurs nodes sont présents    |
| HA     | Possibilité de configurer des bascules automatiques pour assurer la continuité de service     |
| Snapshots et sauvegarde     | Gestion des snapshots et des sauvegardes    |
| API REST    | Automatisation avec l'intégration de l'API REST    |

J'ai récupéré une image ISO sur le [site officiel de Proxmox](https://www.proxmox.com/en/) et j'ai rendu une clé USB bootable avec l'image récupérée. Je ne vais pas détailler l'installation de Proxmox VE, de nombreux guides existent et le programme d'installation fournit par Proxmox est clair et efficace.

---

# 2. Configuration de base de Proxmox VE

La première étape est de créer un utilisateur appartenant au groupe "Admin" afin de pouvoir se connecter via le Realm "Proxmox VE authentication server" et non pas avec l'utilisateur standard "root" via "Linux PAM". Pour cela, il faut être dans la vue "Server View", cliquer sur "Datacenter", se rendre dans la section "Permissions", puis "Users" et enfin cliquer sur le bouton "Add".

![alt text](creation_utilisateur_admin.png)

Il est important d'ajouter le groupe "Admin" dans la section "Group" afin que notre utilisateur puisse disposer de toutes les permissions nécessaires.