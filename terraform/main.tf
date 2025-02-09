provider "proxmox" {
  endpoint = "https://<proxmox_ip>:8006/"
  api_token = var.api_token
  insecure = true
  ssh {
    agent = true
    username = "root"
  }
}