"""Generate ic_launcher.png and ic_launcher_foreground.png at all densities."""
from PIL import Image
import os

SRC = "assets/new-logo.jpg"

LAUNCHER_SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive icon foreground: 108dp canvas; logo fills the central 72dp safe zone = 66.7%
FOREGROUND_SIZES = {
    "drawable-mdpi":    108,
    "drawable-hdpi":    162,
    "drawable-xhdpi":   216,
    "drawable-xxhdpi":  324,
    "drawable-xxxhdpi": 432,
}
LOGO_RATIO = 72 / 108  # logo occupies central 72dp of 108dp canvas

img = Image.open(SRC).convert("RGBA")

print("Launcher icons:")
for density, size in LAUNCHER_SIZES.items():
    dst_dir = f"android/app/src/main/res/{density}"
    os.makedirs(dst_dir, exist_ok=True)
    dst = f"{dst_dir}/ic_launcher.png"
    img.resize((size, size), Image.LANCZOS).save(dst, "PNG", optimize=True)
    print(f"  {dst}  ({size}x{size})")

print("Adaptive foreground:")
for density, canvas in FOREGROUND_SIZES.items():
    dst_dir = f"android/app/src/main/res/{density}"
    os.makedirs(dst_dir, exist_ok=True)
    dst = f"{dst_dir}/ic_launcher_foreground.png"
    logo_size = int(canvas * LOGO_RATIO)
    offset = (canvas - logo_size) // 2
    # Transparent canvas with logo centred
    canvas_img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    logo = img.resize((logo_size, logo_size), Image.LANCZOS)
    canvas_img.paste(logo, (offset, offset), logo)
    canvas_img.save(dst, "PNG", optimize=True)
    print(f"  {dst}  ({canvas}x{canvas}, logo {logo_size}x{logo_size})")

# Also update assets/icon.png (used by flutter_launcher_icons if re-run)
img.resize((1024, 1024), Image.LANCZOS).save("assets/icon.png", "PNG", optimize=True)
print("  assets/icon.png  (1024x1024)")

print("Done.")
