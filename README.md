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

# Latest development

Oberon is currently actively developed at
[Oberon-experimental](https://github.com/andreaspirklbauer/Oberon-experimental).

