import os
import hashlib
import shutil
from collections import defaultdict
from tqdm import tqdm

def calculate_hash(filepath, block_size=65536):
    """Calcule le hash SHA-256 d'un fichier."""
    sha256 = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            for block in iter(lambda: f.read(block_size), b''):
                sha256.update(block)
        return sha256.hexdigest()
    except IOError as e:
        print(f"Attention: Impossible de lire le fichier {filepath}: {e}")
        return None

def find_duplicates(folder_path):
    """
    Trouve les fichiers en double et retourne un dictionnaire de listes de doublons.
    """
    if not os.path.isdir(folder_path):
        print(f"Erreur: Le dossier '{folder_path}' n'existe pas.")
        return {}

    hashes = defaultdict(list)
    image_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.bmp')
    
    files_to_scan = [f for f in os.listdir(folder_path) if f.lower().endswith(image_extensions)]

    print(f"Analyse de {len(files_to_scan)} images dans '{folder_path}'...")
    
    for filename in tqdm(files_to_scan, desc="Analyse des images"):
        filepath = os.path.join(folder_path, filename)
        file_hash = calculate_hash(filepath)
        if file_hash:
            hashes[file_hash].append(filepath)
            
    return {hash_val: paths for hash_val, paths in hashes.items() if len(paths) > 1}

def report_and_copy_duplicates(duplicates, destination_folder):
    """
    Affiche un rapport et copie tous les fichiers en double vers un dossier de destination.
    """
    if not duplicates:
        print("\n🎉 Aucune image en double n'a été trouvée !")
        return

    print(f"\n🚨 RAPPORT : {len(duplicates)} groupe(s) d'images en double trouvé(s) 🚨\n")
    
    # Créer une liste unique de tous les fichiers à copier
    all_files_to_copy = []
    
    for i, (hash_val, paths) in enumerate(duplicates.items()):
        print(f"--- Groupe de doublons n°{i+1} (seront copiés) ---")
        for filepath in paths:
            print(f"  -> {os.path.basename(filepath)}")
            all_files_to_copy.append(filepath)
        print("-" * 50)
    
    print(f"\nPréparation de la copie de {len(all_files_to_copy)} fichiers vers '{destination_folder}'...")
    
    # Créer le dossier de destination s'il n'existe pas
    os.makedirs(destination_folder, exist_ok=True)
    
    copied_count = 0
    # Copier les fichiers avec une barre de progression
    for source_path in tqdm(all_files_to_copy, desc="Copie des doublons"):
        try:
            # shutil.copy2 préserve les métadonnées comme la date de modification
            shutil.copy2(source_path, destination_folder)
            copied_count += 1
        except Exception as e:
            print(f"\nErreur lors de la copie de {os.path.basename(source_path)}: {e}")
            
    print(f"\n✅ Copie terminée. {copied_count} fichiers ont été copiés dans le dossier des doublons.")


if __name__ == "__main__":
    # --- CHEMINS À CONFIGURER ---
    # Le dossier contenant toutes vos images téléchargées
    SOURCE_FOLDER = r"C:\Users\owenm\Downloads\modeles_image"
    # Le dossier où les doublons seront copiés
    DESTINATION_FOLDER = r"C:\Users\owenm\Downloads\doublons_modeles_image"
    
    print("="*60)
    print("Lancement de l'outil d'isolation de doublons")
    print("Les fichiers originaux ne seront pas modifiés.")
    print("="*60)
    
    duplicate_groups = find_duplicates(SOURCE_FOLDER)
    report_and_copy_duplicates(duplicate_groups, DESTINATION_FOLDER)
    
    print("\nOpération terminée.")