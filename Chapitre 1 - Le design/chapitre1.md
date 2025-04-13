> Ce document contient les livrables issues de la phase de design du homelab. On doit se poser les bonnes questions pour répondre efficacement au besoin de départ, à savoir, disposer d'un environnement où l'on peut déployer rapidement des serveurs prêt à l'emploi pour divers cas d'usage.

---

# 1. Le hardware

<> Cette section est susceptible d'évoluer avec le temps. Des évolutions peuvent être appliquées au fur et à mesure du temps avec l'acquisition de plus de compute pour améliorer les performances et la résilience ainsi que la mise en place d'un système de stockage plus adapté comme un NAS.

Pour mettre en place ce homelab, il nous faut un appareil qui dispose de suffisemment de compute soit au moins 32Go de RAM et 16vCPU ainsi qu'un minimum d'espace disque soit 1To. De plus, cet machine va être disponible tout le temps 24h/24 7j/7, il est donc important de prendre une solution qui ne compose pas trop d'énergie.

| Date      | Compute      | Stockage      | Niveau de maturité      |
|:-:    |:-:    |:-:    |:-:    |
| 11/04/2025      | 1 node - E3B Mini PC (32Go RAM, 16 vCPU, 512Go SSD)     | 1 node - E3B Mini PC (512Go SSD)     | 1 🐟      |
---

# 1. Les environnements

Le homelab va être divisé en deux sous-réseaux principaux. Le premier ayant pour objectif d'héberger les divers services utiles au bon fonctionnement du homelab. Le second sera dédié au déploiement et à l'utilisation des VMs et containers pour les tests futures de technologie, OS, etc.

| Nom      | Description      | Adressage      |
|:-:    |---    |---    |
| Core      | Environnement de base du homelab      | 192.168.100.0/24      |
| VMS      | Environnement de déploiement des VMs      | 192.168.200.0/24      |

---

# 2. Les services

Pour disposer d'un environnement fonctionnel et confortable, nous avons besoin de différents services que l'on va détailler dans les sous-sections suivantes.

## 2.1. Firewall

Il s'agit de la seul VM qui aura une interface réseau directement sur mon réseau local (infine le WAN d'un point de vue Firewall) et de ce fait obtiendra une IP en 192.168.1.0/24. L'objectif est gérer les autorisations concernant les communications entrantes et sortantes au niveau du homelab. Le choix technique se portera sur la solution `PFSense`.

## 2.2. Serveur DNS

Le DNS va nous permettre d'utiliser les noms associées à nos VM plutôt que les IP. Le choix technique se portera sur la solution `bind9`.

## 2.3. Machine d'administration centrale

Cette VM sera le point d'entrée vers les ressources du homelab. L'objectif est d'avoir une machine en frontal juste derrière le firewall avec un accés SSH ouvert depuis le WAN (mon réseau local) accessible à certaines IP. Cette machine pourra faire office de rebond et pourra héberger un certains nombre d'outils.

## 2.4. Serveur de versionning

Le serveur de versionning permettra la centralisation des différents éléments relatifs à notre infrastructure notammenent concernant l'infrastructure as code avec Terraform et Ansible. De plus, cette VM ouvre la possibilité d'automatiser nos déploiements de VM futures via les runner et les fonctionnalités de la CI/CD. Le choix technique se portera sur la solution `Gitlab-ce`.

## 2.5. Stack d'observabilité

L'objectif est de disposer d'outils nous permettant de monitorer et de superviser grâce à la collecte des metriques ainsi qu'à l'alerting. Le choix technique se portera sur la "suite" `Prometheus/Grafana`.

## 2.6. Dashboard central

Afin de facilité l'administration du homelab et l'utilisation des différents service, nous allons mettre en place un dashboard moderne et confortable afin d'inventorier l'intégralité des services mis à disposition au sein du homelab. Le choix technique se portera sur `Homepage`

---

# 3. Schéma réseau physique

![alt text](schema_physique.png)

---

# 4. Schéma réseau logique

![alt text](schema_logique.png)

---

# 5. Priorisation

Afin de disposer rapidement d'un homelab fonctionnel avec le minimum de services requis, nous allons définir different niveaux de maturité avec les mises en place des différents services qui y sont associées.

| Niveau     | Description      | Services     | Déploiement
|---    |:-:    |:-:    |:-:    |
| 🐟    | Le homelab est fonctionnel, il est possible de déployer des VMs préconfigurées à la main via des templates.      | Firewall, DNS, machine d'administration     | Template de VM sur Proxmox
| 🐬     | Le déploiement des VM est uniforme et automatisé. La machine de rebond centralisée peut communiquer avec l'entièreté des machines.      | Gitlab-ce, Terraform, Ansible     | Template de VM sur Proxmox avec Terraform et Ansible dans une pipeline Gitlab CI/CD 
| 🐳    | La stack d'observabilité est en place et le homepage prêt à l'emploi avec une évolution dynamique.     | Prometheus, Grafana, Homepage       | Image préconfigurée sur Proxmox avec Terraform et Ansible dans une pipeline Gitlab CI/CD

---

# 6. Todo lists

## 🐟

- [ ] Niveau 1
    - [x] Installation de Proxmox VE
    - [x] Configuration de Proxmox VE
        - [x] Création de l'utilisateur d'administration
        - [x] Mise en place des bons dépôts pour l'update
        - [x] Mise en place de la sauvegarde déportée
        - [x] Configuration des interfaces vmbr1 et vmbr2
        - [x] Tester le bon fonctionnement
    - [x] Installation de PFSense
        - [x] Importer l'ISO de PFSense
        - [x] Configurer la VM avec trois interfaces (vmbr0, vmbr1 et vmbr2)
        - [x] Installer l'OS via l'ISO
        - [x] Rendre disponible l'interface d'administration depuis le WAN (réseau local)
    - [x] Créer un template de Debian 12
        - [x] Importer l'ISO de Debian 12
        - [x] Installer l'OS avec les éléments suivants
            - [x] Nom : debian12-template.homelab
            - [x] Disque : LVM partionnement manuel
            - [x] Service : openssh-server
            - [x] Utilisateur : Création de l'utilisateur d'administration
            - [x] Authentification : Intégrer la clé SSH publique de l'utilisateur de la machine de gestion centralisée
            - [x] Utilisateur : Création de l'utilisateur ansible (group sudo)
            - [x] Authentification : Intégrer la clé SSH publique de l'utilisateur ansible
            - [x] Réseau : Configuration statique 192.168.30.1/24
            - [x] Tester le bon fonctionnement avec le déploiement d'un VM de test
            - [x] Convertir en tant que template
    - [x] Créer un template de RockyLinux 9
        - [x] Importer l'ISO de RockyLinux 9
        - [x] Installer l'OS avec les éléments suivants
            - [x] Nom : rocky9-template.homelab
            - [x] Disque : LVM partionnement manuel
            - [x] Service : openssh-server
            - [x] Utilisateur : Création de l'utilisateur d'administration
            - [x] Authentification : Intégrer la clé SSH publique de l'utilisateur de la machine de gestion centralisée
            - [x] Utilisateur : Création de l'utilisateur ansible
            - [x] Authentification : Intégrer la clé SSH publique de l'utilisateur ansible
            - [x] Réseau : Configuration statique 192.168.30.2/24
            - [x] Tester le bon fonctionnement avec le déploiement d'un VM de test
            - [x] Convertir en tant que template
    - [ ] Installation du DNS (Bind9)
        - [ ] Mise en place de l'OS via les templates
        - [ ] Installation de bind9
        - [ ] Configuration de la zone DNS et du forwarder
        - [ ] Modification de la configuration du résolveur DNS pour admin-core
        - [ ] Test de la résolution interne depuis admin-core
        - [ ] Test de la résolution externe depuis admin-core