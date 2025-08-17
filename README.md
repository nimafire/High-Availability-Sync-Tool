# Failover Manager

**Failover Manager** is a lightweight high-availability script that manages a **floating IP** and keeps two servers synchronized using **rsync + NFS mounts**.  
It ensures that when the master server goes down and the floating IP switches to the slave, data remains consistent.  
When the master comes back online, the script automatically synchronizes changes back.

---

## Features
- Automatic floating IP monitoring
- Switch between **NFS (master active)** and **local storage (failover mode)**
- Bi-directional synchronization (master ↔ local)
- Systemd service for auto start & restart
- Logging to `/var/log/failover_manager.log`

---

## Requirements
- Linux server (tested on Ubuntu/Debian)
- `rsync` installed on both servers
- `nfs-common` (or equivalent) installed
- Root SSH access between servers
- Two servers + one floating IP

---

## Installation

Run the following commands step by step:

```bash
# Create the script
sudo nano /usr/local/bin/failover_manager.sh

# Paste the script content inside, then save and exit

# Make it executable
sudo chmod +x /usr/local/bin/failover_manager.sh

# Create the systemd service
sudo nano /etc/systemd/system/failover_manager.service

# Paste the following content inside, then save and exit
[Unit]
Description=Failover Manager Script
After=network.target

[Service]
ExecStart=/usr/local/bin/failover_manager.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable failover_manager
sudo systemctl start failover_manager

# Check status
sudo systemctl status failover_manager

# View logs
tail -f /var/log/failover_manager.log
