> Ce document contient les livrables issus de la mise en place du service `acme`. L'objectif est de pouvoir disposer d'un outil de gestion de nos certificats utilisés par les services hébergés au sein du homelab.

---

# 1. Création de la VM

Nous allons utiliser le template `debian12-template` créé lors du chapitre 4. Sur Proxmox on créé un clone complet à partir de ce template. Voici les caractéristiques de la VM :

| OS      | Hostname     | Adresse IP | Interface réseau | vCPU    | RAM   | Stockage
|:-:    |:-:    |:-:    |:-:    |:-:    |:-:    |:-:
| Debian 12.10     | acme-core      | 192.168.100.248    | vmbr1 (core)    | 1     | 1024   | 20Gio

Il faut également penser à activer la sauvegarde automatique de la VM sur Proxmox en l'ajoutant au niveau de la politique de sauvegarde précédemment créée.

---

# 2. Modification mineure de l'OS

Modification de la configuration réseau avec le fichier `/etc/network/interfaces`

```bash
auto ens19
iface ens19 inet static
    address 192.168.100.248/24
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

A présent, nous changons le hostname de la VM pour que ce soit `acme-core.homelab`, puis nous modifions le contenu de son résolveur DNS local `/etc/hosts`

```bash
sudo hostnamectl set-hostname acme-core.homelab
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

A présent, on peut tester que les résolutions DNS des noms de domaine interne `.homelab` ainsi que les noms de domaines externes fonctionnent correctement en passant par notre serveur DNS `dns-core.homelab` accessible via l'IP `192.168.100.253`

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

# 3. Installation de ACME

En tant que root, on exécute le script suivant qui va nous permettre de récupérer `acme.sh`

```bash
curl https://get.acme.sh | sh
```

On recharge l'environnement (le .bashrc) de l'utilisateur root, puis on valide l'installation de acme.sh en vérifiant la version

```bash
. ~/.bashrc
acme.sh --version
```

# 4. Génération du Token pour l'API de Cloudflare

L'objectif est de générer un token pour intéragir avec l'API de Cloudflare. Celui-ci doit disposer des droits sur la zone DNS `ng-hl.com` avec les permissions en écriture.

On initie les variables d'environnement nécessaires concernant les informations du token précédemment créé puis de l'ID du compte de Cloudflare.

```bash
export CF_Token="XXX"
export CF_Account_ID="XXX"
export ACME_CA="https://acme-v02.api.letsencrypt.org/directory"
```

---

# 5. Vérification

On peut vérifier que le script acme.sh est fonctionnel avec la commande ci-dessous.

```bash
acme.sh --register-account -m <mail>
```

---

# 6. Génération du wildcard certificat

Pour rappel, nous allons générer un certificat wildcard utilisable pour l'ensemble de nos services hébergés sur le homelab.

On créé l'aborescence nécessaire pour stocker proprement les éléments du certificat

```bash
mkdir -p /etc/ssl/certs/wildcard.ng-hl.com
mkdir -p /etc/ssl/private/wildcard.ng-hl.com
chmod 700 /etc/ssl/private/wildcard.ng-hl.com
```

On spécifie que l'on souhaite utiliser Let's Encrypt

```bash
acme.sh --set-default-ca --server letsencrypt
```

On génère le certificat wildcard

```bash
acme.sh --issue --dns dns_cf -d *.ng-hl.com --keylength ec-256 --server letsencrypt
```

On installe le certificat sur le système avec les noms des éléments correspondants

```bash
acme.sh --install-cert -d '*.ng-hl.com' \
  --cert-file /etc/ssl/certs/wildcard.ng-hl.com/fullchain.cer \
  --key-file /etc/ssl/private/wildcard.ng-hl.com/privkey.key \
  --ca-file /etc/ssl/certs/wildcard.ng-hl.com/ca.cer \
  --fullchain-file /etc/ssl/certs/wildcard.ng-hl.com/fullchain.pem
```

---

# 7. Renouvellement automatique

Pour commencer, on génère une paire de clé SSH spécifique pour l'utilisateur root de `acme-core`

> Les commandes ci-dessous sont exécutées en tant que root

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_acme -C "Utilisateur root acme"
```

On téléverse la clé publique pour l'utilisateur d'administration `ngobert` sur le serveur `vaultwarden-core.homelab`

```bash
ssh-copy-id -i ~/.ssh/id_acme.pub ngobert@vaultwarden-core.homelab
```

Enfin, on édite le fichier `~/.ssh/config`

```bash
Host vaultwarden-core.homelab
  User root
  IdentityFile ~/.ssh/id_acme
```

On test le bon fonctionnement de la connexion SSH

```bash
ssh ngobert@vaultwarden-core.homelab
```

A présent, nous allons automatiser le déploiement sur les VM hébergeant un applicatif exposé avec le certificat.

```bash
mkdir -p /root/acme-deploy
touch /root/acme-deploy/targets.yml
```

Contenu du fichier `/root/acme-deploy/targets.yml. Ici on anticipe le fait que la reload_cmd peut être différente car en plus du nom du service, ce n'est pas assurer que les futurs applicatifs tournent sous Docker.

```yaml
targets:
  - host: vaultwarden-core.homelab
    user: ngobert
    type: docker
    cert_path: /opt/vaultwarden/ssl/
    reload_cmd: docker restart vaultwarden
```

On créé le script de vérification et de déploiement `/root/acme-deploy/acme-deploy.sh` (le paquet `yq` doit être installé sur la VM : `sudo apt install -y yq`)

```bash
#!/bin/bash
set -euo pipefail

CONFIG_FILE="/root/acme-deploy/targets.yml"
LOCAL_CERT="/etc/ssl/certs/wildcard.ng-hl.com/fullchain.cer"
LOCAL_KEY="/etc/ssl/private/wildcard.ng-hl.com/privkey.key"
LOCAL_CA="/etc/ssl/certs/wildcard.ng-hl.com/ca.cer"
LOCAL_FULLCHAIN="/etc/ssl/certs/wildcard.ng-hl.com/fullchain.pem"

# Installation du certificat
acme.sh --install-cert -d '*.ng-hl.com' \
  --cert-file "$LOCAL_FULLCHAIN" \
  --key-file "$LOCAL_KEY" \
  --ca-file "$LOCAL_CA" \
  --fullchain-file "$LOCAL_CERT"

nb_targets=$(yq '.targets | length' "$CONFIG_FILE")

for index in $(seq 0 $((nb_targets - 1))); do
  HOST=$(yq -r ".targets[$index].host" "$CONFIG_FILE")
  USER=$(yq -r ".targets[$index].user" "$CONFIG_FILE")
  DEST_PATH=$(yq -r ".targets[$index].cert_path" "$CONFIG_FILE" | sed 's|/$||')
  RELOAD_CMD=$(yq -r ".targets[$index].reload_cmd" "$CONFIG_FILE")

  echo "Syncing cert to $HOST..."

  # Calcul checksums locaux
  LOCAL_SUM_CERT=$(sha256sum "$LOCAL_CERT" | awk '{print $1}')
  LOCAL_SUM_KEY=$(sha256sum "$LOCAL_KEY" | awk '{print $1}')

  # Calcul checksums distants (on capture erreurs en cas de fichier absent)
  REMOTE_SUM_CERT=$(ssh "${USER}@${HOST}" "sha256sum '$DEST_PATH/fullchain.cer' 2>/dev/null || echo 'missing'" | awk '{print $1}')
  REMOTE_SUM_KEY=$(ssh "${USER}@${HOST}" "sha256sum '$DEST_PATH/privkey.key' 2>/dev/null || echo 'missing'" | awk '{print $1}')

  echo "Local cert checksum:  $LOCAL_SUM_CERT"
  echo "Remote cert checksum: $REMOTE_SUM_CERT"
  echo "Local key checksum:   $LOCAL_SUM_KEY"
  echo "Remote key checksum:  $REMOTE_SUM_KEY"

  if [[ "$LOCAL_SUM_CERT" != "$REMOTE_SUM_CERT" || "$LOCAL_SUM_KEY" != "$REMOTE_SUM_KEY" ]]; then
    echo "Changes detected, copying certs..."

    scp "$LOCAL_CERT" "${USER}@${HOST}:$DEST_PATH/fullchain.cer"
    scp "$LOCAL_KEY" "${USER}@${HOST}:$DEST_PATH/privkey.key"

    echo "Reloading service on $HOST..."
    ssh "${USER}@${HOST}" "$RELOAD_CMD"

    echo "Deployment completed for $HOST."
  else
    echo "Certificate already up to date on $HOST."
  fi

  echo "----------------------------------------"
done
```

On rend le script exécutable

```bash
chmod +x /root/acme-deploy/acme-deploy.sh
```

Enfin, on créé le fichier de log et le crontab correspondant

```bash
touch /var/log/acme-deploy.sh
```

```bash
30 14 * * * /root/acme-deploy/acme-deploy.sh >> /var/log/acme-deploy.log 2>&1
```

---

# 8. Test

On force le renouvellement du certificat

```bash
acme.sh --renew -d '*.ng-hl.com' --force
```

Enfin, on simule l'exécution du cron précédemment créé avec le script `acme-deploy.sh`

```bash
/root/acme-deploy/acme-deploy.sh >> /var/log/acme-deploy.log 2>&1
```