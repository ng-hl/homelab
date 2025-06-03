> Ce document contient les livrables issus de la mise en place du service de coffre fort avec la solution open source Bitwarden compatible, `Vaultwarden`. L'objectif est de pouvoir disposer d'un coffre fort dans le cadre d'une utilisation personnelle et adapté pour le homelab.

---

# 1. Création de la VM

> Modification récente pour le hostname notamment concernant le domaine. `vaultwarden-core.ng-hl.com`

Nous allons utiliser le template `debian12-template` créé lors du chapitre 4. Sur Proxmox on créé un clone complet à partir de ce template. Voici les caractéristiques de la VM :

| OS      | Hostname     | Adresse IP | Interface réseau | vCPU    | RAM   | Stockage
|:-:    |:-:    |:-:    |:-:    |:-:    |:-:    |:-:
| Debian 12.10     | vaultwarden-core      | 192.168.100.249    | vmbr1 (core)    | 1     | 2048   | 20Gio

Il faut également penser à activer la sauvegarde automatique de la VM sur Proxmox en l'ajoutant au niveau de la politique de sauvegarde précédemment créée.

---

# 2. Modification mineure de l'OS

Modification de la configuration réseau avec le fichier `/etc/network/interfaces`

```bash
auto ens19
iface ens19 inet static
    address 192.168.100.249/24
    gateway 192.168.100.254
```

> __Un point important !__ Pendant la création du template `debian12-template` la désactivation de l'IPv6 n'a pas été faite. Il faut donc faire cela à la main pour chaque VM déployées et noter l'information quelque part pour ajouter cette configuration lorsque nous aurons Ansible pour le déploiement des VM.

Désactivation permanente de l'IPv6. Nous devons éditer ce fichier de configuration `/etc/sysctl.conf`

```bash
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

Enfin, nous devons recharger la configuration courante.

```bash
sudo sysctl -p
```

A présent, nous changons le hostname de la VM pour que ce soit `vaultwarden-core.homelab`, puis nous modifions le contenu de son résolveur DNS local `/etc/hosts`

```bash
sudo hostnamectl set-hostname vaultwarden-core.homelab
```

Nous allons maintenant modifier la configuration du résolveur DNS de la machine.

```bash
# Installation du daemon systemd-resolved
sudo apt install -y systemd-resolved

# Purge de resolvconf (obsolète)
sudo apt purge resolvconf

# Activation au démarrage du daemon systemd-resolved
sudo systemctl enable systemd-resolved --now

# Modification du fichier /etc/systemd/resolved.conf avec les éléments suivants
DNS=192.168.100.253
FallbackDNS=1.1.1.1
Domains=~.

# Restart du daemon systemd-resolved
sudo systemctl restart systemd-resolved

# Suppression du fichier /etc/resolv.conf
sudo rm /etc/resolv.conf

# Création du nouveau lien symbolique avec /etc/resolv.conf
sudo ln -s /run/systemd/resolve/stub-resolv.conf  /etc/resolv.conf
```

A présent, on peut tester que les résolutions DNS des noms de domaine interne `.homelab`, `.ng-hl.com` ainsi que les noms de domaines externes fonctionnent correctement en passant par notre serveur DNS `dns-core.homelab` accessible via l'IP `192.168.100.253`

```bash
resolvectl status
Global
          Protocols: +LLMNR +mDNS -DNSOverTLS DNSSEC=no/unsupported
   resolv.conf mode: stub
 Current DNS Server: 192.168.100.253
Fallback DNS Servers 1.1.1.1
          DNS Domain ~.

Link 2 (ens19)
Current Scopes: LLMNR/IPv4
     Protocols: -DefaultRoute +LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
```

Enfin, on test quelques résolutions DNS avec notre nouvelle configuration

```bash
dig +short dns-core.homelab
192.168.100.253
```

```bash
dig +short google.com
216.58.214.78
```

---

# 3. Installation de VaultWarden

> Il est nécessaire d'installer Docker Engine en amont puis on ajoute l'utilisateur `ngobert` au groupe `docker`

On créé la structure de répertoire pour hébergé le service vaultwarden ainsi que le certificat wildcard

```bash
mkdir -p /opt/vaulwarden/ssl
```

Pour téléverser les éléments du certificat depuis acme-core, on utilise rsync

```bash
sudo rsync -avz /root/.acme.sh/*.ng-hl.com_ecc/{fullchain.cer,*.ng-hl.com.key}   ngobert@vaultwarden-core.homelab:/opt/vaultwarden/ssl/
```

On renomme la clé privée du certificat pour plus de simplicité d'utilisation

```bash
mv \*.ng-hl.com.key privkey.key 
```

On créé le volumes Docker

```bash
docker volume create vaultwarden-volume
```

On exécute le container Docker avec la dernière version de l'image vaultwarden, les variables d'environnement et les volumes nécessaires

```bash
docker run --detach --name vaultwarden \
  --env DOMAIN="https://vaultwarden-core.ng-hl.com" \
  --env ROCKET_TLS='{certs="/ssl/fullchain.cer",key="/ssl/privkey.key"}' \
  --env ROCKET_PORT=443 \
  --volume vaultwarden-volume:/data \
  --volume /opt/vaultwarden/ssl/:/ssl:ro \
  --restart unless-stopped \
  --publish 443:443 \
  vaultwarden/server:latest
```

Activation de l'interface d'administration

```bash
# Création du token
openssl rand -hex 32

# Exécution du container
docker run --detach --name vaultwarden \
  --env DOMAIN="https://vaultwarden-core.ng-hl.com" \
  --env ROCKET_TLS='{certs="/ssl/fullchain.cer",key="/ssl/privkey.key"}' \
  --env ROCKET_PORT=443 \
  --env ADMIN_TOKEN="XXXXX" \
  --volume vaultwarden-volume:/data \
  --volume /opt/vaultwarden/ssl/:/ssl:ro \
  --restart unless-stopped \
  --publish 443:443 \
  vaultwarden/server:latest
```

---

# 4. Exposition du service sur le réseau local

Pour rendre le service `vaultwarden` sur le réseau local, il est nécessaire d'ouvrir le flux à destination de cette VM sur le port 443 et du serveur DNS du homelab sur UDP/53 et TCP/53. De plus, il est nécessaire d'ajouter un route statique en passant par 192.168.1.49 (le pfsense) pour joindre le réseau 192.168.100.0/24.

---

# 5. Accés au service

Pour se connecter au service VaultWarden : `https://vaultwarden-core.ng-hl.com` ou `https://vaultwarden.ng-hl.com` (CNAME associé)

Pour se connecter à l'interface d'administration : `https://vaultwarden-core.ng-hl.com/admin` (utiliser le token précédemment créé)