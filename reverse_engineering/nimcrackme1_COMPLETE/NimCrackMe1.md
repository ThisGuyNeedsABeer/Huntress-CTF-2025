# NimCrackMe1 - Reverse Engineering Walkthrough

## Challenge Overview

**Binary:** `nimcrackme1.exe`  
**Type:** Windows PE Executable (x64)  
**Language:** Nim  
**Challenge:** Find the flag in the format `flag{md5-value}`

### Binary Information
- **MD5:** `e9d44810ae608950e4c76bf98a8b4676`
- **SHA256:** `47d7fa30cfeeba6cc42e75e97382ab05002a6cd0ebb4d622156a6af84fda7d5e`
- **Base Address:** `0x140000000`
- **Size:** `0x38000` (224 KB)

---

## Solution Process

### Step 1: Initial Analysis

Loading the binary in IDA Pro, we can see it's a Nim-compiled executable. Nim binaries have distinctive naming conventions with mangled function names containing metadata.

### Step 2: Finding the Entry Point

Starting from the main entry points, we trace through:
1. `mainCRTStartup` → `NimMain` → `NimMainInner` → `NimMainModule`
2. `NimMainModule` calls `main__crackme_u20()`

### Step 3: Analyzing the Main Function

Decompiling `main__crackme_u20()` at address `0x140012b84` reveals the core logic:

```c
buildEncodedFlag__crackme_u18(&v13);  // Build encoded flag
// ...
xorStrings__crackme_u3(&v11, &v2, v1);  // XOR decode the flag
```

The program:
1. Builds an encoded flag
2. XORs it with a key stored in global variables
3. Performs time-based checks before displaying the result

### Step 4: Extracting the Encoded Flag

The `buildEncodedFlag__crackme_u18` function constructs a byte array at runtime. Analysis of the pseudocode reveals it creates a 38-byte array with values set at specific indices:

```python
encoded_bytes = [
    40, 5, 12, 71, 18, 75, 21, 92, 9, 18, 23, 85, 9, 75, 66, 8,
    85, 90, 69, 88, 68, 87, 69, 119, 93, 84, 68, 92, 69, 19, 89, 91,
    71, 66, 94, 89, 22, 93
]
```

The function assigns these bytes to positions `v10[8]` through `v10[45]` (38 bytes total).

### Step 5: Finding the XOR Key

In the main function, the XOR operation uses global variables:
```c
v1[0] = TM__cGo7QGde1ZstH4i7xlaOag_5;
v1[1] = &TM__cGo7QGde1ZstH4i7xlaOag_4;
xorStrings__crackme_u3(&v11, &v2, v1);
```

Reading the memory at `TM__cGo7QGde1ZstH4i7xlaOag_4` (address `0x140021ae0`) reveals:

**XOR Key:** `Nim is not for malware!`

### Step 6: Decoding the Flag

The flag is decoded using a repeating XOR cipher:

```python
xor_key = b"Nim is not for malware!"

decoded = []
for i, byte in enumerate(encoded_bytes):
    key_byte = xor_key[i % len(xor_key)]
    decoded.append(byte ^ key_byte)

decoded_string = bytes(decoded).decode('ascii')
print(f"Decoded flag: {decoded_string}")
```

### Step 7: The Solution

Running the decode operation:

```
Total bytes: 38
Decoded flag: flag{852ff73f9be462962d949d563743b86d}
```

---

## Flag

**`flag{852ff73f9be462962d949d563743b86d}`**

---