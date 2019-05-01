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
