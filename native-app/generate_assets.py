import os
from PIL import Image

def generate_icons(source_path, res_dir):
    try:
        img = Image.open(source_path).convert("RGBA")
    except Exception as e:
        print(f"Error opening icon source: {e}")
        return

    sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192
    }

    for density, size in sizes.items():
        resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
        folder = os.path.join(res_dir, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        resized_img.save(os.path.join(folder, "ic_launcher.png"))
        resized_img.save(os.path.join(folder, "ic_launcher_foreground.png"))
        resized_img.save(os.path.join(folder, "ic_launcher_round.png"))
        print(f"Saved icons for {density}")

def generate_splashes(source_path, res_dir):
    try:
        source_img = Image.open(source_path).convert("RGBA")
    except Exception as e:
        print(f"Error opening splash source: {e}")
        return

    sizes = {
        'drawable-port-mdpi': (320, 480),
        'drawable-port-hdpi': (480, 800),
        'drawable-port-xhdpi': (720, 1280),
        'drawable-port-xxhdpi': (960, 1600),
        'drawable-port-xxxhdpi': (1280, 1920),
        'drawable-land-mdpi': (480, 320),
        'drawable-land-hdpi': (800, 480),
        'drawable-land-xhdpi': (1280, 720),
        'drawable-land-xxhdpi': (1600, 960),
        'drawable-land-xxxhdpi': (1920, 1280),
    }

    # Use white background #FFFFFF
    bg_color = (255, 255, 255, 255)

    for folder_name, (width, height) in sizes.items():
        bg = Image.new('RGBA', (width, height), bg_color)
        s_width, s_height = source_img.size
        # scale down the logo to fit nicely in the center (make it 50% width instead of 80% to look better on splash)
        ratio = min(width * 0.5 / s_width, height * 0.5 / s_height)
        new_w = int(s_width * ratio)
        new_h = int(s_height * ratio)
        
        resized_logo = source_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        x = (width - new_w) // 2
        y = (height - new_h) // 2
        
        # In case the source image is transparent, we paste it effectively over the white bg
        bg.paste(resized_logo, (x, y), resized_logo)
        
        folder = os.path.join(res_dir, folder_name)
        os.makedirs(folder, exist_ok=True)
        bg.save(os.path.join(folder, "splash.png"))
        print(f"Saved splash for {folder_name}")

if __name__ == "__main__":
    icon_source = "/Users/jarvis/.gemini/antigravity/brain/2573d615-0522-4394-9cba-b1c51af3ceed/media__1776112246042.png"
    splash_source = "/Users/jarvis/.gemini/antigravity/brain/2573d615-0522-4394-9cba-b1c51af3ceed/media__1776112257011.png"
    res_dir = "/Users/jarvis/Desktop/workgood/native-app/android/app/src/main/res"
    generate_icons(icon_source, res_dir)
    generate_splashes(splash_source, res_dir)
