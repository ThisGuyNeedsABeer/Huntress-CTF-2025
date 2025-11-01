from PIL import Image, ImageOps, ImageEnhance
import zxingcpp

# Load original cropped MaxiCode image
img = Image.open("maxi.png")

# Convert to grayscale once
gray = ImageOps.grayscale(img)

# Boost contrast heavily
gray = ImageEnhance.Contrast(gray).enhance(5.0)

decoded = False

# Loop over thresholds, sizes, and rotations
for thresh in [80, 100, 120, 140, 160, 180]:
    for size in [400, 600, 800, 1000]:
        for angle in range(0, 360, 15):  # rotate in 15° steps
            # Binarize at threshold
            bw = gray.point(lambda x: 0 if x < thresh else 255, "1")
            # Resize
            bw = bw.resize((size, size), Image.NEAREST)
            # Rotate (expand keeps full image)
            bw_rot = bw.rotate(angle, expand=True)

            # Try decoding
            results = zxingcpp.read_barcodes(bw_rot)
            if results:
                print(f"[SUCCESS] threshold={thresh}, size={size}, rotation={angle}")
                for r in results:
                    print("Format:", r.format)
                    print("Text:", r.text)
                decoded = True
                break
        if decoded:
            break
    if decoded:
        break

if not decoded:
    print("[FAIL] No barcode detected after all passes.")
