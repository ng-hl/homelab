> Ce document contient les livrables issues de la phase d'installation et de configuration de pfSense. L'objectif est de pouvoir disposer d'une solution permettant de gérer simplement et efficacement les ouvertures réseaux entre les différents sous-réseaux du homelab mais également en provenance et à destination du WAN. L'occasion parfait pour jouer un peu avec pfSense.

---

# 1. Installation de pfSense

Aprés avoir récupéré l'ISO de pfSense que le site officiel, plus précisément sur le dépôt officiel car il faut s'inscrire pour obtenir l'ISO de puis le site, j'ai installé pfSense avec une configuration classique sans apporté de particularités majeures.

Ce que l'on souhaite, c'est l'association interfaces / réseau ci-dessous :

| Interface      | Réseau pfSense     | Sous-réseau
|:-:    |:-:    |:-:    |
| vmbr0     | WAN      | Réseau local (maison) |
| vmbr1     | LAN      | Réseau Core (homelab) |
| vmbr2     | OPT      | Réseau VMS (homelab) |



