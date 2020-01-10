# ESP32->PS/2

Micropython ESP32 code that listens at TCP port and
retransmits received packets using PS/2 protocol.

Intended use is to emulate PS/2 keyboard and mouse.

python code receives keyboard events,
converts them to "PS/2 SET2" scancodes and
sends over TCP to ESP32.

PS/2 SET2 is standard power-on default scancode setting
for PS/2 keyboards.

Currently this code doesn't support bidirectional PS/2 so
emulated PS/2 keyboard and mouse port can only send but
can't receive commands from PS/2 for e.g. blink keyboard LEDs,
change scancode set or enable mouse wheel.

# ESP32 PS/2 pins

This is default pinout recommended for ULX3S.
Edit "ps2tn.py" or "ps2recv.py" to use other ESP32 pins.

    assign ps2_keyboard_clk  = gp[11]; // wifi_gpio26
    assign ps2_keyboard_data = gn[11]; // wifi_gpio25
    assign ps2_mouse_clk     = wifi_gpio17;
    assign ps2_mouse_data    = wifi_gpio16;

# telnet input

telnet input is convenient and readily available on most platforms.
Requires no windowing support.
Supports only keyboard (typing), doesnt support mouse.

ESP32: upload "ps2tn.py" and "ps2.py"

    import ps2tn

telnet to ESP32 and start typing. "ps2tn" should echo typed chars.

    telnet 192.168.4.1

# pygame input

pygame input is available on most platforms.
Requires windowing support.
Supports keyboard and mouse.

ESP32: upload "ps2recv.py" and "ps2.py"

    import ps2recv

host: edit "pygame_keyboard_mouse.py" to set IP address of ESP32 and mouse type
(wheel/no_wheel). pygame will open a window that will grab
mouse and keyboard:

    ./pygame_keyboard_mouse.py

Press "PAUSE" key to quit.

# linux input

linux input is available only on linux.
Requires no windowing support.
Supports keyboard (will support mouse later).

ESP32: upload "ps2recv.py" and "ps2.py"

    import ps2recv

for linux input, you need to give user "rw" access to "/dev/input/eventX"
device which represents your keyboard:

    lsinput
    chmod a+rw /dev/input/event3

and then you should maybe edit "linux_keyboard.py" to place keyboard name
(you have seen it using "lsinput") and run the host-side input client
as normal user:

    ./linux_keyboard.py

# TODO

[x] E0-scancodes
[x] telnet interface
[x] unify keyboard mouse
[ ] linux input mouse support
[ ] joystick
