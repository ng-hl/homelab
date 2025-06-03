> Ce document contient les livrables issus de la phase d'installation et de configuration de la machine d'administration centralisée `admin-core`. L'objectif est de pouvoir disposer d'une VM accessible en SSH depuis mon réseau local avec la clé privée SSH (id_admin) utile pour l'accés aux autres VM du sous réseau `core` et `vms`.

---

# 1. Création de la VM

Nous allons utiliser le template `debian12-template` créé lors du chapitre 4. Sur Proxmox on créé un clone complet à partir de ce template. Voici les caractéristiques de la VM :

| OS      | Hostname     | Adresse IP | Interface réseau | vCPU    | RAM   | Stockage
|:-:    |:-:    |:-:    |:-:    |:-:    |:-:    |:-:
| Debian 12.10     | admin-core      | 192.168.100.252    | vmbr1 (core)    | 2     | 4096   | 20Gio

Il faut également penser à activer la sauvegarde automatique de la VM sur Proxmox en l'ajoutant au niveau de la politique de sauvegarde précédemment créée.

---

# 2. Modification mineure de l'OS

Modification de la configuration réseau avec le fichier `/etc/network/interfaces`

```bash
auto ens19
iface ens19 inet static
    address 192.168.100.252/24
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

A présent, nous changons le hostname de la VM pour que ce soit `admin-core.homelab`, puis nous modifions le contenu de son résolveur DNS local `/etc/hosts`

```bash
sudo hostnamectl set-hostname admin-core.homelab
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
         DNS Servers 192.168.100.253
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

> Il est important d'activer le résolveur DNS au niveau de pfSense. Pour les interfaces entrantes `CORE` et `VMS` puis pour l'interface sortante `WAN`.

---

# 3. Configuraiton de l'accés SSH vers les autres machines du sous réseau CORE

On intègre la paire de clé SSH `id_admin` au niveau de l'utilisateur `ngobert`. Pour cela, on créer un répertoire `.ssh` s'il nexiste pas déjà.

```bash
mkdir -p ~/.ssh 
```

A présent nous placons les clés que nous avons généré au moment de la création des templates. Si les clés sont stockés en local la commande `scp` fera parfaitement l'affaire.

```bash
scp homelab_ssh.tar nogbert@192.168.100.252:/home/ngobert/.ssh/ 
```

Voici le résultat final

```bash
ls -l
total 12
-rw-r--r-- 1 ngobert ngobert 110 13 avril 23:10 authorized_keys
-rw------- 1 ngobert ngobert 419 13 avril 19:37 id_admin
-rw-r--r-- 1 ngobert ngobert 110 13 avril 19:37 id_admin.pub
```

> Pour rappel, la clé privée SSH `id_admin.pub` est déjà présente au niveau de l'utilisateur ngobert sur les machines déployées depuis le template. Il n'y a donc pas besoin de les déployer à la main.

Afin de rendre les connexions plus confortables, nous allons éditer notre fichier de configuration SSH `~/.ssh/config` avec les éléments ci-dessous (utilisation de la bonne clé SSH dès que l'on souhaite se connecter sur une VM avec le hostname dans le domaine homelab avec l'utilisateur ngobert)

> Le nom de domaine `ng-hl.com` est ajouté au chapitre 9. L'objectif est de disposer d'un certificat wildcard associé à ce nom de domaine pour accéder à mes services exposés avec un certificat valide garanti par les CA.

```bash
Host *.homelab *.ng-hl.com
  User ngobert
  IdentityFile ~/.ssh/id_admin
```

Pour finir, on peut mettre ne place des alias pour nous connecter plus simplement. Pour cela, nous allons éditer le fichier bashrc de notre utilisateur courant `~/.bashrc`

```bash
alias dns-core='ssh dns-core.homelab'
```

Pour tester immédiatement, on source notre fichier `.bashrc` précédemment modifié

```bash
. ~/.bashrc
```

Pour se connecter à `dns-core.homelab`

```bash
dns-core
Linux dns-core.homelab 6.1.0-33-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.133-1 (2025-04-10) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Wed Apr 16 16:01:41 2025 from 192.168.100.252
```