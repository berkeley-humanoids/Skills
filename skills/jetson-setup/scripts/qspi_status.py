#!/usr/bin/env python3
# Read-only check on the Jetson: is the QSPI boot flash (Macronix MX25U51279G on Orin NX/Nano)
# block-protected? A protected chip ignores the chip erase of the flash tool and reports no error.
# The flash then writes the boot firmware over old data, and the Jetson boots into recovery mode.
# The script moves the QSPI from the spi-nor driver to spidev, reads ID/SR/CR/SCUR, then moves it back.
#
# Usage: sudo python3 qspi_status.py
import ctypes, fcntl, glob, os, time

# The SPI bus number of the QSPI changes between boots; find it by its controller (3270000.spi on T234).
(DEV,) = glob.glob("/sys/bus/platform/devices/3270000.spi/spi_master/spi*/spi*.0")
NAME = os.path.basename(DEV)
SPI_IOC_MESSAGE_2 = 0x40406B00  # _IOW('k', 0, struct spi_ioc_transfer[2])


class Xfer(ctypes.Structure):
    _fields_ = [("tx_buf", ctypes.c_uint64), ("rx_buf", ctypes.c_uint64), ("len", ctypes.c_uint32),
                ("speed_hz", ctypes.c_uint32), ("delay_usecs", ctypes.c_uint16), ("bits_per_word", ctypes.c_uint8),
                ("cs_change", ctypes.c_uint8), ("tx_nbits", ctypes.c_uint8), ("rx_nbits", ctypes.c_uint8),
                ("word_delay_usecs", ctypes.c_uint8), ("pad", ctypes.c_uint8)]


def read(fd, cmd, n):
    # tegra-qspi is half duplex: send the opcode, then read, in one chip-select window.
    tx = ctypes.create_string_buffer(bytes([cmd]), 1)
    rx = ctypes.create_string_buffer(n)
    t = (Xfer * 2)(Xfer(ctypes.addressof(tx), 0, 1, 1_000_000, 0, 8, 0, 1, 1, 0, 0),
                   Xfer(0, ctypes.addressof(rx), n, 1_000_000, 0, 8, 0, 1, 1, 0, 0))
    fcntl.ioctl(fd, SPI_IOC_MESSAGE_2, t)
    return rx.raw


def write(path, value):
    with open(path, "w") as f:
        f.write(value)


write("/sys/bus/spi/drivers/spi-nor/unbind", NAME)
try:
    write(f"{DEV}/driver_override", "spidev")
    write("/sys/bus/spi/drivers/spidev/bind", NAME)
    time.sleep(1)
    fd = os.open("/dev/spidev" + NAME[3:], os.O_RDWR)
    rdid, sr, cr, scur = read(fd, 0x9F, 3).hex(), read(fd, 0x05, 1)[0], read(fd, 0x15, 2)[0], read(fd, 0x2B, 1)[0]
    os.close(fd)
    write("/sys/bus/spi/drivers/spidev/unbind", NAME)
finally:
    write(f"{DEV}/driver_override", "\n")
    write("/sys/bus/spi/drivers/spi-nor/bind", NAME)

bp = sr >> 2 & 0xF
print(f"JEDEC ID {rdid}{'' if rdid == 'c2953a' else '  (not MX25U51279G: register meanings below may differ)'}")
print(f"SR   {sr:#04x}: BP3..0={bp:04b} QE={sr >> 6 & 1} SRWD={sr >> 7 & 1}")
print(f"CR   {cr:#04x}: TB={cr >> 3 & 1} ({'bottom' if cr >> 3 & 1 else 'top'} of the chip is protected when BP != 0)")
print(f"SCUR {scur:#04x}: WPSEL={scur >> 7 & 1}")
print("RESULT: block protection is ON; the flash tool cannot erase the QSPI" if bp or scur >> 7 & 1
      else "RESULT: QSPI is not block-protected")
