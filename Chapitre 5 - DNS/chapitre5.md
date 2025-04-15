> Ce document contient les livrables issues de la phase d'installation et de configuration du service DNS avec `bind9`. L'objectif est de pouvoir disposer d'un service DNS concernant notre zone .homelab. accessible au sein du homelab et depuis mon réseau local.

---

# 1. Création de la VM

Nous allons utiliser le template `debian12-template` créé lors du chapitre précédent. Sur Proxmox on créé un clone complet à partir de ce template. Voici les caractéristiques de la VM :

| OS      | Hostname     | Adresse IP | Interface réseau | vCPU    | RAM   | Stockage
|:-:    |:-:    |:-:    |:-:    |:-:    |:-:    |:-:
| Debian 12.10     | dns-core      | 192.168.100.253    | vmbr1 (core)    | 1     | 512   | 20Gio

Il faut également penser à activer la sauvegarde automatique de la VM sur Proxmox en l'ajoutant au niveau de la politique de sauvegarde précédemment créée.

---

# 2. Modification mineure de l'OS

Modification de la configuration réseau avec le fichier `/etc/network/interfaces`

```bash
auto ens19
iface ens19 inet static
    address 192.168.100.253/24
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

A présent, nous changons le hostname de la VM pour que ce soit `dns-core.homelab`, puis nous modifions le contenu de son résolveur DNS local `/etc/hosts`

```bash
sudo hostnamectl set-hostname dns-core.homelab
```

---

# 3. Installation de bind9

Bind9 est un service DNS trés répandu sur les serveur de type GNU/LInux.

Nous allons commencer par installer les paquets `bind9` et `bind9-doc` qui contient la documentation.

```bash
sudo apt install -y bind9 bind9-doc
```

---

# 4. Configuration de bind9

La première chose que nous allons faire est de configurer le forwarder vers notre `pfSense` en `192.168.100.254`. Ainsi, lorsque nous souhaiterons faire une requête DNS qui n'est pas couverte par notre serveur bind9 la requête sera forwarder vers pfSense qui lui même va renvoyer la requête sur ma box internet sur mon réseau local. Mes VM auront pourrons donc résoudre les noms de domaine d'Internet, non déclarés sur mon bind9. Pour cela, nous éditons le fichier `/etc/bind9/named.conf.options`

```bash
# On décommente les lignes concernant le forwarder puis on rensigne l'IP désirée
forwarders {
    192.168.100.254;
}
```

Nous configurons les directions vers le fichier qui correspond au nom de domaine `.homelab` et pour le fichier qui va gérer la résolution inversée en `192.168.*.*`. On édite le fichier `/etc/bind/named.conf.default-zones`

```bash
zone "homelab" {
    type master;
    file "/etc/bind/db.homelab";
}

zone "168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168";
}
```

Maintenant, nous créons le fichier `/etc/bind/db.homelab` qui va être le fichier descriptif de la zone couvrant le nom de domaine `.homelab`

```bash
;
; BIND data file for local homelab zone
;
$TTL    604800
@       IN      SOA     homelab. root.homelab. (
                        2504151         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns-core.homelab.

; CORE
dns-core        IN      A       192.168.100.253
admin-core      IN      A       192.168.100.252
```

Enfin, nous créons le fichier `/etc/bind/db.100.168.192` qui va être le fichier descriptif pour le résolution DNS inverse concernant le domaine `.homelab`

```bash
;
; BIND reverse data file for local homelab zone
;
$TTL    604800
@       IN      SOA     dns-core.homelab. root.homelab. (
                        2504151         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      dns-core.homelab.

; CORE
253 IN      PTR     dns-core.homelab.
252 IN      PTR     admin-core.homelab.
```

On peut vérifier la syntaxe de nos fichiers de zones avec les commandes suivantes

```bash
# Zone homelab
sudo named-checkzone homelab /etc/bind/db.homelab 
zone homelab/IN: loaded serial 2504151
OK

# Zone inverse homelab
sudo named-checkzone 100.168.192.in-addr.arpa /etc/bind/db.100.168.192 
zone 100.168.192.in-addr.arpa/IN: loaded serial 2504151
OK
```

Une fois que la syntaxe de fichier de configuration des zones bind précédemment éditer est correcte, nous pouvons recharger le daemon `bind9` pour appliquer les modifications.

```bash
sudo systemctl reload bind9
```

On peut également vérifier que le service est bel et bien exécuter

```bash
sudo systemctl status bind9
```

---

# 5. Vérification

Pour le moment, nous ne disposons que d'une seule VM, `dns-core`. Cependant, nous pouvons vérifier directement sur ce noeud que le service DNS répond correctement avec les enregistrements DNS que nous avons ajoutés au niveau des fichiers de configuration pour la zone `.homelab` que ce soit pour la recherche DNS directe ou inverse.

```bash
# Test résolution DNS
dig +short @192.168.100.253 dns-core.homelab
192.168.100.253

dig +short @192.168.100.253 admin-core.homelab
192.168.100.252

# Test pour la résolution DNS inversée
dig -x 192.168.100.253 @192.168.100.253 +short
dns-core.homelab.

dig -x 192.168.100.252 @192.168.100.253 +short
admin-core.homelab.
```

Le serveur DNS avec le service `bind9` est à présent fonctionnel.