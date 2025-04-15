> Ce document contient les livrables issus de la phase d'installation et de configuration de la machine d'administration centralisée `admin-core`. L'objectif est de pouvoir disposer d'une VM accessible en SSH depuis mon réseau local avec la clé privée SSH utile pour l'accés aux autres VM du sous réseau `core` et `vms`.

---

# 1. Création de la VM

Nous allons utiliser le template `debian12-template` créé lors du chapitre 4. Sur Proxmox on créé un clone complet à partir de ce template. Voici les caractéristiques de la VM :

| OS      | Hostname     | Adresse IP | Interface réseau | vCPU    | RAM   | Stockage
|:-:    |:-:    |:-:    |:-:    |:-:    |:-:    |:-:
| Debian 12.10     | admin-core      | 192.168.100.252    | vmbr1 (core)    | 2     | 4096   | 20Gio

Il faut également penser à activer la sauvegarde automatique de la VM sur Proxmox en l'ajoutant au niveau de la politique de sauvegarde précédemment créée.

---

# 2. Modification mineure de l'OS
