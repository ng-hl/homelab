# Homelab

---

## 0. Schema

![](image.png)

## 0.1 Todo

- [] **Homelab 🛠**  
  - [] **Proxmox**
    - [x] Install proxmox VE on mini-PC
    - [x] Create specific admin user
    - [x] Create terraform specific user (terraform-deploy) with sepcific roles
  - [] **Gitlab**
    - [x] Install Gitlab server
    - [x] Create specific admin user
    - [x] Create project for our deploy pipeline

---

## 1. Proxmox

### 1.1. Install proxmox VE

---

### 1.2. Terraform with Proxmox

Sources :
- Thank you, Stephane Robert for this ressource ! [blog.stephane-robert.info](https://blog.stephane-robert.info/docs/virtualiser/type1/proxmox/terraform/#configuration-de-proxmox)

Role creation `TerraformProv` for specific Terraform user which we will use to deploy ressources on Proxmox

```bash
pveum role add TerraformProv -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"
```

User creation `terraform-deploy`

```bash
pveum user add terraform-deploy@pve --password <password>
```

Role attribution for terraform-deploy user with specific permissions previously set on TerraformProv role.

```bash
pveum aclmod / -user terraform-deploy@pve -role TerraformProv
```

Token `Terraform token` generation. This one will be used to deploy ressources on Proxmox

```bash
pveum user token add terraform-deploy@pve terraform -expire 0 -privsep 0 -comment "Terraform token"
```

### 1.3. Template generation

We will generate a template VM to use it with our terraform-deploy token. 

```bash
apt install -y libguestfs-tools
```

Let's move on the Proxmox's iso directory

```bash
cd /var/lib/vz/template/iso
```

Download Ubuntu 20.04 server cloud image

```bash
wget https://cloud-images.ubuntu.com/releases/20.04/release/ubuntu-20.04-server-cloudimg-amd64.img
```

```bash
sudo virt-customize -a ubuntu-20.04-server-cloudimg-amd64.img --install qemu-guest-agent
```