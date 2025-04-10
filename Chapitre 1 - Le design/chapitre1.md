> Ce document contient les livrables issues de la phase de design du homelab. On doit se poser les bonnes questions pour répondre efficacement au besoin de départ, à savoir, disposer d'un environnement où l'on peut déployer rapidement des serveurs prêt à l'emploi pour divers cas d'usage.

---

# 1. Les environnements

Le homelab va être divisé en deux vlans principaux. Le premier ayant pour objectif d'héberger les divers services utiles au bon fonctionnement du homelab. Le second sera dédié au déploiement et à l'utilisation des VMs et containers pour les tests futures de technologie, OS, etc.

| Nom      | Description      | VLAN      | Adressage      |
|---    |:-:    |:-:    |:-:    |
| Core      | Environnement de base du homelab      | 100      | 192.168.100.0/24      |
| VMS      | Environnement de déploiement des VMs      | 200      | 192.168.200.0/24      |

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
    - [ ] Installation de Proxmox VE
    - [ ] Configuration des VLAN sur Proxmox VE
    - [ ] Installation de PFSense
        - [ ] Importer l'ISO de PFSense
        - [ ] Configurer la VM avec deux interface (vmbr0 et vmbr1)
        - [ ] Installer l'OS via l'ISO
        - [ ] Rendre disponible l'interface d'administration depuis le WAN (réseau local)
    - [ ] Créer un template de Debian 12
        - [ ] Importer l'ISO de Debian 12
        - [ ] Installer l'OS avec les éléments suivants
            - [ ] Nom : debian12-template.homelab
            - [ ] Disque : LVM partionnement manuel
            - [ ] Service : opensessh-server
            - [ ] Création de l'utilisateur
            - [ ] Réseau : Configuration statique 192.168.30.1/24
            - [ ] Intégrer la clé SSH publique de l'utilisateur de la machine de gestion centralisée
            - [ ] Tester le bon fonctionnement avec le déploiement d'un VM de test
    - [ ] Créer un template de RockyLinux 9
        - [ ] Importer l'ISO de RockyLinux 9
        - [ ] Installer l'OS avec les éléments suivants
            - [ ] Nom : rockylinux9-template.homelab
            - [ ] Disque : LVM partionnement manuel
            - [ ] Service : opensessh-server
            - [ ] Création de l'utilisateur
            - [ ] Réseau : Configuration statique 192.168.30.2/24
            - [ ] Intégrer la clé SSH publique de l'utilisateur de la machine de gestion centralisée
            - [ ] Tester le bon fonctionnement avec le déploiement d'un VM de test
    - [ ] Installation du DNS (Bind9)
        - [ ] Mise en place de l'OS via les templates
        - [ ] Installation de bind9
        - [ ] Configuration de la zone DNS et du forwarderœ