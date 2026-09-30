import os
from PIL import Image, ImageDraw

res_dir = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')
logo_path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'images', 'logo.png')

logo = Image.open(logo_path).convert('RGBA')

# 1. Colors.xml
values_dir = os.path.join(res_dir, 'values')
os.makedirs(values_dir, exist_ok=True)
colors_xml_path = os.path.join(values_dir, 'colors.xml')
with open(colors_xml_path, 'w', encoding='utf-8') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
''')
print("Created colors.xml with white background.")

# 2. mipmap-anydpi-v26 xmls
anydpi_dir = os.path.join(res_dir, 'mipmap-anydpi-v26')
os.makedirs(anydpi_dir, exist_ok=True)

adaptive_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''

with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
    f.write(adaptive_xml)

with open(os.path.join(anydpi_dir, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
    f.write(adaptive_xml)

print("Created adaptive icon XML files in mipmap-anydpi-v26.")

# Densities and sizes
# Legacy icon: 48, 72, 96, 144, 192
# Foreground icon: 108, 162, 216, 324, 432
densities = {
    'mipmap-mdpi': (48, 108),
    'mipmap-hdpi': (72, 162),
    'mipmap-xhdpi': (96, 216),
    'mipmap-xxhdpi': (144, 324),
    'mipmap-xxxhdpi': (192, 432),
}

def create_scaled_logo(target_box_size):
    tw, th = target_box_size
    lw, lh = logo.size
    ratio = min(tw / lw, th / lh)
    nw, nh = int(lw * ratio), int(lh * ratio)
    return logo.resize((nw, nh), Image.Resampling.LANCZOS)

for folder, (legacy_sz, fg_sz) in densities.items():
    folder_path = os.path.join(res_dir, folder)
    os.makedirs(folder_path, exist_ok=True)
    
    # --- A. Legacy Square Icon (White background + logo) ---
    legacy_canvas = Image.new('RGBA', (legacy_sz, legacy_sz), (255, 255, 255, 255))
    # Give 12% padding inside
    box_sz = int(legacy_sz * 0.78)
    scaled = create_scaled_logo((box_sz, box_sz))
    ox = (legacy_sz - scaled.size[0]) // 2
    oy = (legacy_sz - scaled.size[1]) // 2
    legacy_canvas.paste(scaled, (ox, oy), scaled)
    
    # Save ic_launcher.png
    legacy_canvas.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')
    
    # --- B. Legacy Round Icon (Circle white background + logo) ---
    round_canvas = Image.new('RGBA', (legacy_sz, legacy_sz), (0, 0, 0, 0))
    draw = ImageDraw.Draw(round_canvas)
    draw.ellipse((0, 0, legacy_sz - 1, legacy_sz - 1), fill=(255, 255, 255, 255))
    round_box_sz = int(legacy_sz * 0.72)
    scaled_r = create_scaled_logo((round_box_sz, round_box_sz))
    rox = (legacy_sz - scaled_r.size[0]) // 2
    roy = (legacy_sz - scaled_r.size[1]) // 2
    round_canvas.paste(scaled_r, (rox, roy), scaled_r)
    round_canvas.save(os.path.join(folder_path, 'ic_launcher_round.png'), 'PNG')
    
    # --- C. Adaptive Foreground Icon (Transparent canvas, logo in safe center) ---
    fg_canvas = Image.new('RGBA', (fg_sz, fg_sz), (0, 0, 0, 0))
    # Safe zone is 66dp of 108dp (~61%)
    fg_box_sz = int(fg_sz * 0.58)
    scaled_fg = create_scaled_logo((fg_box_sz, fg_box_sz))
    fox = (fg_sz - scaled_fg.size[0]) // 2
    foy = (fg_sz - scaled_fg.size[1]) // 2
    fg_canvas.paste(scaled_fg, (fox, foy), scaled_fg)
    fg_canvas.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), 'PNG')
    
    print(f"Generated icons for {folder}: legacy ({legacy_sz}x{legacy_sz}), fg ({fg_sz}x{fg_sz})")

print("\nSuccessfully generated all Android launcher icons with white background and company logo!")
