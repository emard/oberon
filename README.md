# Oberon for ULX3S attempt by EMARD

It boots and shows 1024x768 70Hz picture.
FleaFPGA's
[https://github.com/Basman74/Oberon_SDRAM](https://github.com/Basman74/Oberon_SDRAM)
slightly reworked and cleanup'd

wget [oberon disk image](http://www.projectoberon.net/zip/RISCimg.zip),
unzip, and write it raw to SD card:

    wget http://www.projectoberon.net/zip/RISCimg.zip
    unzip RISCimg.zip
    dd if=RISC.img of=/dev/mmcblk0

Image will initialize first 2 primary partitions (out of 4) required for
oberon, rest of SD card (free space) can be used with
other OS (linux) by creating new primary partition(s)
there and making new filesystem(s).

# Disk partition

Oberon expects it's "partition" to start at 512-byte sector number 524288,
which is byte offset 268435456. Oberon won't touch the first two 512-byte
sectors of it's own partition so it's become a convention in some Oberon
emulators to leave off the first 268436480 bytes , resulting in a shortened
disk image. You can tell you are working with a shortened Oberon disk image
if it starts with 8d a3 1e 9b which is the on-disk representation of the
directory sector mark, 0x9b1ea38d. The current RISC Oberon kernel will only
address 67108864 (67MB) of on-disk storage due to an internal sector table
limit, although the on-disk structures should allow a volume size of 141 GB
if that sector table limit were removed. It is safe for now to expect Oberon
to only use 67 MB of disk space... nobody has removed that limit yet in RISC
Oberon.

# Latest development

Oberon is currently actively developed at
[Oberon-experimental](https://github.com/andreaspirklbauer/Oberon-experimental).

