import network
sta_if = network.WLAN(network.STA_IF)
sta_if.active(True)
sta_if.connect("ra", "GigabyteBrix")
#import uftpd

#from os import mount
#from machine import SDCard
#mount(SDCard(slot=3),"/sd")

#import ps2recv

#import ecp5
#ecp5.prog("apple2.bit.gz")
#import disk2
#import ps2tn

#import ecp5
#ecp5.prog("jupiter_ace.bit.gz")
#import ps2tn
