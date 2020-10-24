# start oberon from micropython
import os
from machine import SDCard, Pin
import ecp5

os.mount(SDCard(slot=3),"/sd")
# load bitstream but don't start it while SD is mounted (close=False)
fpga_size = { 0x21111043:12, 0x41111043:25, 0x41112043:45, 0x41113043:85 }
ecp5.prog("/sd/oberon/ulx3s_%df_oberon_ps2mouse_esp32ps2kbdrecv.bit" % fpga_size[ecp5.idcode()],close=False)
os.umount("/sd")
# release all SD pins to HI-Z
p12=Pin(12,Pin.IN)
p13=Pin(13,Pin.IN)
p14=Pin(14,Pin.IN)
p15=Pin(15,Pin.IN)
# after SD is unmounted, start bitstream
ecp5.prog_close()
# network receiver for PS/2 keyboard and mouse
#import ps2recv