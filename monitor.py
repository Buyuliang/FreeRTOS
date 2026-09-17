#!/usr/bin/env python3
# Minimal serial monitor for the USB-Serial-JTAG port. Usage: monitor.py [port]
import os, sys, time
port = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM1"
fd = os.open(port, os.O_RDONLY | os.O_NONBLOCK)
try:
    while True:
        try:
            d = os.read(fd, 256)
            if d: os.write(1, d)
            else: time.sleep(0.02)
        except BlockingIOError:
            time.sleep(0.02)
except KeyboardInterrupt:
    pass
finally:
    os.close(fd)
