import os
import hashlib
import shutil
import requests
import json
from collections import defaultdict
from tqdm import tqdm

import firebase_admin
from firebase_admin import credentials, storage

# --- Fonctions (Les premières sont inchangées) ---
def calculate_hash(filepath, block_size=65536):
    sha256 = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            for block in iter(lambda: f.read(block_size), b''):
                sha256.update(block)
        return sha256.hexdigest()
    except IOError as e:
        print(f"\nAttention: Impossible de lire le fichier {filepath}: {e}")
        return None

def find_duplicates(folder_path):
    if not os.path.isdir(folder_path):
        print(f"Erreur: Le dossier '{folder_path}' n'existe pas.")
        return {}
    hashes = defaultdict(list)
    image_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.bmp')
    files_to_scan = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f)) and f.lower().endswith(image_extensions)]
    if not files_to_scan:
        print(f"Aucun fichier image trouvé dans '{folder_path}'.")
        return {}
    print(f"Analyse de {len(files_to_scan)} images dans '{folder_path}'...")
    for filename in tqdm(files_to_scan, desc="Analyse des images"):
        filepath = os.path.join(folder_path, filename)
        file_hash = calculate_hash(filepath)
        if file_hash:
            hashes[file_hash].append(filepath)
    return {hash_val: paths for hash_val, paths in hashes.items() if len(paths) > 1}

def download_image(url, destination_path):
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()
        with open(destination_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"✅ Image téléchargée avec succès vers : {os.path.basename(destination_path)}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur de téléchargement depuis {url}: {e}")
        return False

def upload_to_firebase(source_path, firebase_bucket):
    filename = os.path.basename(source_path)
    destination_blob_name = f"models/{filename}"
    try:
        blob = firebase_bucket.blob(destination_blob_name)
        print(f"📤 Upload de '{filename}' vers Firebase Storage...")
        blob.upload_from_filename(source_path, content_type='image/jpeg')
        blob.make_public()
        print(f"✅ Upload terminé. URL publique : {blob.public_url}")
        return blob.public_url
    except Exception as e:
        print(f"❌ Erreur lors de l'upload sur Firebase: {e}")
        return None

# --- La fonction de mise à jour redevient simple et stricte ---
def update_json_file(clean_model_id, new_image_url, json_folder_path, brand_name):
    """Met à jour le fichier JSON avec un ID propre et exact."""
    try:
        json_filename = f"{brand_name}.json"
        json_filepath = os.path.join(json_folder_path, json_filename)
        
        with open(json_filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        model_found = False
        for model in data['models']:
            if model['id'] == clean_model_id:
                print(f"📝 Mise à jour de l'URL pour le modèle '{clean_model_id}' dans '{json_filename}'...")
                model['imageUrl'] = new_image_url
                model_found = True
                break
        
        if not model_found:
            print(f"❌ Modèle avec l'ID exact '{clean_model_id}' non trouvé dans '{json_filename}'.")
            return False
            
        with open(json_filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Fichier JSON mis à jour.")
        return True
    except Exception as e:
        print(f"❌ Erreur lors de la mise à jour du fichier JSON pour l'ID '{clean_model_id}': {e}")
        return False

# === LA LOGIQUE DE NETTOYAGE EST ICI ===
def process_duplicates_interactively(duplicates, source_folder, dest_folder, json_folder, firebase_bucket, all_brands):
    if not duplicates:
        print("\n🎉 Aucune image en double n'a été trouvée !")
        return
    print(f"\n🚨 {len(duplicates)} groupe(s) d'images en double trouvé(s). Début du processus de remplacement. 🚨")
    os.makedirs(dest_folder, exist_ok=True)
    group_num = 0
    for hash_val in list(duplicates.keys()):
        paths = duplicates[hash_val]
        group_num += 1
        print("\n" + "="*60)
        print(f"--- Traitement du Groupe de doublons n°{group_num}/{len(duplicates)} ---")
        for i, filepath in enumerate(paths):
            print(f"  {i + 1}: {os.path.basename(filepath)}")
        while True:
            choice_str = input("\nQuelle image remplacer ? (Entrez le numéro, 's' pour sauter, 'q' pour quitter) > ")
            if choice_str.lower() == 's': break
            if choice_str.lower() == 'q': return
            try:
                choice_index = int(choice_str) - 1
                if 0 <= choice_index < len(paths):
                    file_to_replace_path = paths[choice_index]
                    filename = os.path.basename(file_to_replace_path)
                    print(f"Vous avez choisi de remplacer : {filename}")
                    new_url = input("Entrez l'URL de la nouvelle image > ").strip()
                    if not new_url: continue
                    new_image_temp_path = os.path.join(dest_folder, filename)
                    if not download_image(new_url, new_image_temp_path): continue
                    print(f"🔄 Remplacement de l'ancien fichier dans '{source_folder}'...")
                    shutil.copy2(new_image_temp_path, file_to_replace_path)
                    new_firebase_url = upload_to_firebase(file_to_replace_path, firebase_bucket)
                    if not new_firebase_url: continue
                    
                    # --- NOUVELLE LOGIQUE DE NETTOYAGE DE L'ID ---
                    filename_base = os.path.splitext(filename)[0]
                    
                    # 1. Détecter la marque
                    found_brand = None
                    for brand_name in all_brands:
                        if filename_base.lower().startswith(brand_name.lower()):
                            found_brand = brand_name
                            break
                    
                    if not found_brand:
                        print(f"❌ Impossible de déterminer la marque pour '{filename}'. Passage au suivant.")
                        continue

                    # 2. Nettoyer le nom du fichier pour enlever les préfixes redondants
                    clean_filename_base = filename_base
                    redundant_prefix = f"{found_brand}_{found_brand}_"
                    if clean_filename_base.lower().startswith(redundant_prefix):
                        print(f"ℹ️ Préfixe redondant '{found_brand}_' détecté et supprimé.")
                        # On supprime la première occurrence de "marque_"
                        clean_filename_base = clean_filename_base[len(found_brand)+1:]

                    # 3. Créer l'ID final pour le JSON
                    # On part du principe que la marque est déjà au début et correcte.
                    # On remplace juste les `_` restants par des `-`.
                    clean_model_id = clean_filename_base.replace('_', '-')

                    json_updated = update_json_file(clean_model_id, new_firebase_url, json_folder, found_brand)
                    
                    if json_updated:
                         print(f"\n🎉 Remplacement complet pour '{filename}' terminé avec succès! 🎉")
                    else:
                         print(f"\n⚠️ Remplacement partiel pour '{filename}'. L'image a été changée mais le JSON n'a pas pu être mis à jour.")
                    break
                else:
                    print("Numéro invalide.")
            except ValueError:
                print("Entrée invalide.")

if __name__ == "__main__":
    SOURCE_FOLDER = r"C:\Users\owenm\Downloads\modeles_image"
    DESTINATION_FOLDER = r"C:\Users\owenm\Downloads\doublons_modeles_image"
    JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
    FIREBASE_CREDENTIALS_PATH = r"C:\Users\owenm\Documents\spot_my_car\car-spotter-app-779f2-firebase-adminsdk-fbsvc-4a7d0bed3f.json"
    FIREBASE_BUCKET_NAME = "car-spotter-app-779f2.firebasestorage.app"
    
    print("="*60)
    print("Lancement de l'outil de remplacement de doublons d'images")
    print("="*60)
    
    try:
        print("Chargement des noms de marques depuis les fichiers JSON...")
        brand_filenames = [f for f in os.listdir(JSON_MODELS_FOLDER) if f.endswith('.json')]
        all_brands = [os.path.splitext(f)[0] for f in brand_filenames]
        all_brands.sort(key=len, reverse=True)
        print(f"✅ {len(all_brands)} marques chargées.")
    except FileNotFoundError:
        print(f"❌ ERREUR CRITIQUE: Le dossier JSON '{JSON_MODELS_FOLDER}' est introuvable.")
        exit()

    try:
        print("Initialisation de Firebase Admin...")
        if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
            raise FileNotFoundError(f"Fichier de crédentials introuvable à : '{FIREBASE_CREDENTIALS_PATH}'.")
        
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred, {'storageBucket': FIREBASE_BUCKET_NAME})
        
        print(f"Connexion au bucket '{FIREBASE_BUCKET_NAME}'...")
        bucket = storage.bucket()
        print("✅ Firebase initialisé et bucket accessible.")
        
    except Exception as e:
        print(f"\n❌ ERREUR CRITIQUE: Impossible d'initialiser Firebase ou d'accéder au bucket.")
        print(f"   Détail de l'erreur: {e}")
        exit()

    duplicate_groups = find_duplicates(SOURCE_FOLDER)
    
    process_duplicates_interactively(
        duplicate_groups,
        SOURCE_FOLDER,
        DESTINATION_FOLDER,
        JSON_MODELS_FOLDER,
        bucket,
        all_brands
    )
    
    print("\nOpération terminée.")