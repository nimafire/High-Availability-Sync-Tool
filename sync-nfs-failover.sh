#!/bin/bash

# ==== config ====
FLOAT_IP="172.31.133.100"
MASTER_IP="172.31.133.116"
NFS_MOUNT_POINTS=("/www-data" "/www-config")
LOCAL_DIRS=("/home/www-data" "/home/www-config")
SYMLINKS=("/www-data" "/www-config")
LOGFILE="/var/log/failover_manager.log"

# ==== log ====
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

# ==== mount NFS ====
mount_nfs() {
    for i in "${!NFS_MOUNT_POINTS[@]}"; do
        mountpoint -q "${NFS_MOUNT_POINTS[$i]}"
        if [ $? -ne 0 ]; then
            mount -t nfs "$MASTER_IP:${SYMLINKS[$i]}" "${NFS_MOUNT_POINTS[$i]}"
            log "Mounted NFS ${SYMLINKS[$i]} on ${NFS_MOUNT_POINTS[$i]}"
        fi
    done
}

# ==== unmount NFS ====
unmount_nfs() {
    for mountp in "${NFS_MOUNT_POINTS[@]}"; do
        umount "$mountp" 2>/dev/null && log "Unmounted $mountp"
    done
}

# ==== Switch to local ====
switch_to_local() {
    unmount_nfs
    for dir in "${SYMLINKS[@]}"; do
        [ -L "$dir" ] && rm "$dir" && log "Removed symlink $dir"
    done
    for i in "${!SYMLINKS[@]}"; do
        ln -s "${LOCAL_DIRS[$i]}" "${SYMLINKS[$i]}"
        log "Created symlink ${SYMLINKS[$i]} -> ${LOCAL_DIRS[$i]}"
    done
}

# ==== Switch to NFS ====
switch_to_nfs() {
    for dir in "${SYMLINKS[@]}"; do
        [ -L "$dir" ] && rm "$dir" && log "Removed symlink $dir"
    done
    mount_nfs
}

# ==== sync local -> master ====
sync_local_to_master() {
    log "Sync local to master"
    rsync -avz --delete --rsync-path="sudo rsync" /home/www-data/ "$MASTER_IP:/www-data/"
    rsync -avz --delete --rsync-path="sudo rsync" /home/www-config/ "$MASTER_IP:/www-config/"
}

# ==== sync master -> local ====
sync_master_to_local() {
    log "Sync master to local"
    rsync -avz --delete --rsync-path="sudo rsync" "$MASTER_IP:/www-data/" /home/www-data/
    rsync -avz --delete --rsync-path="sudo rsync" "$MASTER_IP:/www-config/" /home/www-config/
}

# MAIN
while true; do
    ping -c 1 "$FLOAT_IP" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "FLOAT IP is reachable (master active)"
        if [ -L /www-data ] && [ "$(readlink /www-data)" == "/home/www-data" ]; then
            sync_local_to_master
        fi
        switch_to_nfs
        sync_master_to_local
    else
        log "FLOAT IP is NOT reachable (switching to local)"
        switch_to_local
    fi
    sleep 10  # check each 10 sec
done
