#!/usr/bin/env python3
import os
import struct
from datetime import datetime

def get_timedatestamp(path):
    with open(path, "rb") as f:
        data = f.read()
    # Check for 'PE\0\0' header and extract offset from DOS header
    if len(data) < 0x3C + 4:
        return None
    pe_offset = struct.unpack("<I", data[0x3C:0x40])[0]
    if len(data) < pe_offset + 8 + 4:
        return None
    if data[pe_offset:pe_offset+4] != b'PE\x00\x00':
        return None
    timestamp = struct.unpack("<I", data[pe_offset+8:pe_offset+12])[0]
    return timestamp

def main():
    bins = [f for f in os.listdir('.') if f.lower().endswith('.bin')]
    results = []
    for filename in bins:
        tds = get_timedatestamp(filename)
        if tds:
            results.append((filename, tds))

    # Sort newest to oldest
    results.sort(key=lambda x: x[1], reverse=True)

    print(f"{'Filename':<30} {'Hex':<12} {'UTC Time'}")
    print("=" * 60)
    for name, tds in results:
        try:
            dt = datetime.utcfromtimestamp(tds)
            print(f"{name:<30} 0x{tds:08X}  {dt} UTC")
        except (OSError, OverflowError, ValueError):
            print(f"{name:<30} 0x{tds:08X}  [Invalid timestamp]")

if __name__ == "__main__":
    main()
