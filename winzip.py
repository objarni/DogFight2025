# ...existing code...

import zipfile
import os

def create_zip():
    zip_path = "Dogfight2025.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        assets_dir = "zig-out/bin/assets"
        for root, _, files in os.walk(assets_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, assets_dir)
                path_in_archive = os.path.join("assets", arcname)
                print(f"Adding {path_in_archive} to zip")
                zipf.write(file_path, path_in_archive)
        # Add only Dogfight2025.exe from zig-out
        exe_path = os.path.join("zig-out", "bin/Dogfight2025.exe")
        if os.path.exists(exe_path):
            exe = "Dogfight2025.exe"
            print(f"Adding {exe} to zip")
            zipf.write(exe_path, exe)

if __name__ == "__main__":
    print("Creating zip file...")
    create_zip()
