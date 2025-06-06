> Ce document contient les livrables issus de la mise en place du service `kresus`, une solution de gestion des comptes bancaires.

---

# 1. Création de la VM

Nous allons utiliser le template `debian12-template` créé lors du chapitre 4. Sur Proxmox on créé un clone complet à partir de ce template. Voici les caractéristiques de la VM :

| OS      | Hostname     | Adresse IP | Interface réseau | vCPU    | RAM   | Stockage
|:-:    |:-:    |:-:    |:-:    |:-:    |:-:    |:-:
| Debian 12.10     | kresus-vms      | 192.168.200.4    | vmbr2 (vms)    | 1     | 2024   | 20Gio

Il faut également penser à activer la sauvegarde automatique de la VM sur Proxmox en l'ajoutant au niveau de la politique de sauvegarde précédemment créée.

---

# 2. Modification mineure de l'OS

Modification de la configuration réseau avec le fichier `/etc/network/interfaces`

```bash
auto ens19
iface ens19 inet static
    address 192.168.200.4/24
    gateway 192.168.200.4
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

A présent, nous changons le hostname de la VM pour que ce soit `kresus-vms.homelab`, puis nous modifions le contenu de son résolveur DNS local `/etc/hosts`

```bash
sudo hostnamectl set-hostname kresus-vms.homelab
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

A présent, on peut tester que les résolutions DNS des noms de domaine internes `.homelab` et concernant les services exposés `.ng-hl.com` ainsi que les noms de domaines externes fonctionnent correctement en passant par notre serveur DNS `dns-core.homelab` accessible via l'IP `192.168.100.253`

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

# 3. Installation de Kresus

> Il est nécessaire d'installer `Docker engine` pour procéder à la mise en place de kresus via docker compose

On créé le volume Docker pour avoir la persistance des données concernant la base de données Postgresql

```bash
docker volume create pgdata
```

Nous utilisons Docker compose pour disposer de deux container. Le premier étant celui qui porte l'applicatif kresus et le second va permettre de loadbalancer le traffic arrivant en HTTPS vers le container kresus. On créé le fichier `/opt/kresus/docker-compose.yml`

```bash
---
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: <db_user>
      POSTGRES_PASSWORD: <db_password>
      POSTGRES_DB: <db_name>
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: unless-stopped

  kresus:
    image: bnjbvr/kresus
    container_name: kresus
    restart: unless-stopped
    ports:
      - "9876:9876"
    volumes:
      - ./config/kresus.cfg:/config/kresus.cfg:ro
    environment:
      - NODE_ENV=production
      - KRESUS_DB_TYPE=postgres
      - KRESUS_DB_HOST=postgres
      - KRESUS_DB_PORT=5432
      - KRESUS_DB_USERNAME=<db_user>
      - KRESUS_DB_PASSWORD=<db_password>
      - KRESUS_DB_NAME=<db_name>
      - KRESUS_AUTH=<username>:<password>
    depends_on:
      - postgres

  kresus-nginx:
    image: nginx:stable-alpine
    container_name: kresus-nginx
    restart: unless-stopped
    ports:
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certs:/etc/ssl/private:ro
    depends_on:
      - kresus

volumes:
  pgdata:
```

Nous importons les éléments nécessaires au niveau du répertoire `/opt/kresus/certs` pour que le certificat wildcard puisse s'appliquer correctement.

```bash
mkdir -p /opt/kresus/certs
```

On se positionne en tant que root sur la vm `acme-core` qui contient le certificat et la clé privée associée, puis on téléverse les éléments au niveau de notre server `kresus-vms.homelab`

```bash
scp /etc/ssl/certs/wildcard.ng-hl.com/fullchain.pem ngobert@kresus-vms.homelab:/opt/kresus/certs/
scp /etc/ssl/private/wildcard.ng-hl.com/privkey.key ngobert@kresus-vms.homelab:/opt/kresus/crets/privkey.pem
```

Nous créons le fichier de configuration de nginx `/opt/kresus/nginx/conf.d/kresus.conf`

```bash
server {
    listen 443 ssl;
    server_name kresus.ng-hl.com;

    ssl_certificate     /etc/ssl/private/fullchain.pem;
    ssl_certificate_key /etc/ssl/private/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass         http://kresus:9876;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

> Il est nécessaire d'autoriser le flux HTTPS depuis l'interface WAN de pfSense vers l'alias `kresus_vms` pointant vers l'ip `192.168.200.4` soit le service exposé `kresus.ng-hl.com`