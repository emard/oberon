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

Oberon expects it's "partition" to start at 512-byte sector number 524288 =
512x1024, which is byte offset 268435456 = 512x512x1024. Oberon won't touch the first
two 512-byte sectors of it's own partition and start from sector number
524290 = 512x1024+2 so it's become a convention in some Oberon
emulators to leave off the first 268436480 = 512x512x1024 + 2x512 bytes,
resulting in a shortened disk image.

You can tell you are working with a shortened Oberon disk image
if it starts with 8d a3 1e 9b which is the on-disk representation of the
directory sector mark, 0x9b1ea38d. The current RISC Oberon kernel will only
address 67108864 (64MB) = 64x1024x1024 of on-disk storage due to an internal
sector table limit, although the on-disk structures should allow a volume size
of 141 GB if that sector table limit were removed. It is safe for now to expect Oberon
to only use 64 MB of disk space... nobody has removed that limit yet in RISC
Oberon.


    fdisk /dev/sda

    Command (m for help): p
    Disk /dev/sda: 7,42 GiB, 7969177600 bytes, 15564800 sectors
    Disk model: SD/MMC          
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0x00000000

    Device     Boot   Start      End  Sectors  Size Id Type
    /dev/sda1          2048   524287   522240  255M  b W95 FAT32
    /dev/sda2        655360  1179647   524288  256M 83 Linux
    /dev/sda3        524290   655359   131072   64M df BootIt <-- Oberon
    /dev/sda4       1179648 15564799 14385152  6,9G  5 Extended
    /dev/sda5       1181696  3278847  2097152    1G 83 Linux
    /dev/sda6       3280896  3805183   524288  256M 82 Linux swap / Solaris

    Partition table entries are not in disk order.

    hexdump -C /dev/sda3
    00000000  8d a3 1e 9b 03 00 00 00  91 1d 00 00 00 00 00 00  |................|

Here are some disk image examples:

[schierlm image from emu 2019-01-21](https://github.com/schierlm/oberon-risc-emu-enhanced)
has Hilbert etc examples already compiled.

[schierlm modifications releases](https://github.com/schierlm/Oberon2013Modifications)
has different content, no Hilbert etc examples.

Such images can be dumped directly to partition 3 as created above:

    dd if=Oberon-2019-01-21.dsk of=/dev/sda3

or using ESP32 uftpd.py form [esp32ecp5](https://github.com/emard/esp32ecp5)
and direct ESP32 SD offset

    ftp> put Oberon-2019-01-21.dsk sd@268436480

or

    lftp> put Oberon-2019-01-21.dsk -o /sd@268436480

# Quick GUI info

Oberon has no folders. All files are in root.
If any text on the GUI is Middle clicked, it will
executed as if this command has been typed to commandline.

On right bottom window, move cursor down.
Press left click and cursor like slanted "1" will appear.
To compile "Sierpinski" example, on empty line type

    ORP.Compile Sierpinski.Mod

Middle click on "ORP.Compile". On upper right window
compile message will appear.

Then Middle click on "Sierpinski.Draw" to run example, some
pattern will be drawn on big left window.

With Right drag you can select for example "*.Mod"
and then Middle-click on "System.Directory", list of sources
will appear. Right drag on "Sierpinski.Mod" and Middle click
on "Edit.Open" to edit the file. Middle click to "Edit.Store"
to save it.

# Latest development

Oberon is currently actively developed at
[Oberon-experimental](https://github.com/andreaspirklbauer/Oberon-experimental)

Memory configuration
[Oberon-memory](https://github.com/io-core/technotes/blob/main/technote002.md)
