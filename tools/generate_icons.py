#!/usr/bin/env python3
"""
Generate PNG icons from SVG for Flutter Android app.
Requires: pip install cairosvg pillow
"""

import os
import cairosvg
from PIL import Image
import io

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SVG_PATH = os.path.join(BASE_DIR, 'assets', 'icon.svg')

# Icon sizes for different densities
ICON_SIZES = {
    'assets/icon.png': 512,
    'assets/icon_foreground.png': 512,
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    'android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png': 108,
    'android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png': 162,
    'android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png': 216,
    'android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png': 324,
    'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png': 432,
}


def svg_to_png(svg_path: str, size: int) -> bytes:
    """Convert SVG to PNG at specified size."""
    return cairosvg.svg2png(url=svg_path, output_width=size, output_height=size)


def main():
    print(f"Reading SVG from: {SVG_PATH}")

    for relative_path, size in ICON_SIZES.items():
        output_path = os.path.join(BASE_DIR, relative_path)

        # Ensure directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        # Convert and save
        png_data = svg_to_png(SVG_PATH, size)

        with open(output_path, 'wb') as f:
            f.write(png_data)

        print(f"Generated: {relative_path} ({size}x{size})")

    print("\nAll icons generated successfully!")


if __name__ == '__main__':
    main()