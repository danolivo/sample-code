dd if=/dev/zero of=userdisk.fs bs=1M count=1
mkfs.vfat userdisk.fs
sudo mount -t vfat -o loop,umask=0022,gid=1000,uid=1000 userdisk.fs disk

