#!/usr/bin/env python3
import sys
from typing import List, Tuple

# Your large 528-bit prime (from the blog and your input)
PRIME_HEX = "010000000000000000000000000000000000000000000000000000000000000129"
PRIME = int(PRIME_HEX, 16)

def modinv(a, p):
    """Modular inverse using Extended Euclidean Algorithm."""
    if a == 0:
        raise ZeroDivisionError("division by zero")
    lm, hm = 1, 0
    low, high = a % p, p
    while low > 1:
        r = high // low
        nm, new = hm - lm * r, high - low * r
        lm, low, hm, high = nm, new, lm, low
    return lm % p

def lagrange_interpolate_at_zero(shares: List[Tuple[int, int]], prime: int) -> int:
    """Lagrange interpolation to recover f(0) over finite field."""
    total = 0
    for i, (xi, yi) in enumerate(shares):
        num, den = 1, 1
        for j, (xj, _) in enumerate(shares):
            if i == j:
                continue
            num = (num * (-xj)) % prime
            den = (den * (xi - xj)) % prime
        inv_den = modinv(den, prime)
        term = yi * num * inv_den
        total = (total + term) % prime
    return total

def parse_shares(filename: str) -> List[Tuple[int, int]]:
    """Parse lines like 1-deadbeef... into (1, int_value)"""
    shares = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or '-' not in line:
                continue
            x_str, hex_y = line.split('-', 1)
            x = int(x_str)
            y = int(hex_y, 16)
            shares.append((x, y))
    return shares

def main():
    if len(sys.argv) != 2:
        print("Usage: {} <sharefile>".format(sys.argv[0]))
        sys.exit(1)

    sharefile = sys.argv[1]
    shares = parse_shares(sharefile)
    if len(shares) < 2:
        print("Need at least 2 shares to reconstruct the secret.")
        sys.exit(1)

    secret = lagrange_interpolate_at_zero(shares, PRIME)
    print("\n[+] Recovered secret (int):", secret)
    secret_hex = hex(secret)[2:].rjust(len(PRIME_HEX), '0')
    print("[+] Recovered secret (hex):", secret_hex)

    try:
        secret_bytes = bytes.fromhex(secret_hex)
        print("[+] Secret as UTF-8 (if printable):", secret_bytes.decode('utf-8'))
    except UnicodeDecodeError:
        print("[!] Secret is not valid UTF-8.")
    except ValueError:
        print("[!] Could not convert hex to bytes.")

if __name__ == "__main__":
    main()
