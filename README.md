# BOOSTSTRAP

Inside the Arch Linux ISO, after creating the two partitions on the target drive:

Use `cfdisk` to create or manage the partitions.

Partition 1: `/efi` (1 GiB)
Partition 2: `/` (root)

To verify the partitions, run:

`lsblk`

To start the script:

```bash
curl -sL https://raw.githubusercontent.com/br4ndol/arch-old/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh
```

# Arch Setup

Run with
```
cd arch
sudo ./setup.sh
```

---
