import os
import shutil
import requests
import json
from tqdm import tqdm

from PIL import Image

try:
    import pyperclip
    PYPERCLIP_AVAILABLE = True
except ImportError:
    PYPERCLIP_AVAILABLE = False

import firebase_admin
from firebase_admin import credentials, storage

# --- Fonctions Utilitaires (inchangées) ---
def find_broken_images(folder_path):
    if not os.path.isdir(folder_path):
        print(f"Erreur: Le dossier '{folder_path}' n'existe pas.")
        return []
    broken_files = []
    image_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.bmp')
    files_to_scan = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f)) and f.lower().endswith(image_extensions)]
    print(f"Vérification de {len(files_to_scan)} images dans '{folder_path}'...")
    for filename in tqdm(files_to_scan, desc="Analyse des images"):
        filepath = os.path.join(folder_path, filename)
        try:
            with Image.open(filepath) as img:
                img.verify()
        except Exception:
            print(f"\n-> Image corrompue/invalide détectée : {filename}")
            broken_files.append(filepath)
    return broken_files

def download_image(url, destination_path):
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()
        with open(destination_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"✅ Image téléchargée avec succès.")
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

# === LA FONCTION DE MISE À JOUR FINALE AVEC INTERACTION MANUELLE ===
def update_json_file(clean_filename_base, new_image_url, json_folder_path, brand_name):
    """
    Tente une recherche automatique. Si elle échoue, demande l'ID exact à l'utilisateur.
    """
    try:
        json_filename = f"{brand_name}.json"
        json_filepath = os.path.join(json_folder_path, json_filename)
        with open(json_filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # --- Tentative 1 : Recherche Automatique par Normalisation ---
        normalized_target_id = clean_filename_base.lower().replace('_', '').replace('-', '')
        model_to_update = None
        for model in data['models']:
            json_model_id = model.get('id', '')
            normalized_json_id = json_model_id.lower().replace('_', '').replace('-', '').replace('½','0.5')
            if normalized_json_id == normalized_target_id:
                model_to_update = model
                break
        
        # --- Tentative 2 : Fallback Manuel si l'automatique échoue ---
        if not model_to_update:
            print(f"\n⚠️  La recherche automatique a échoué pour '{clean_filename_base}'.")
            manual_id = input(f"    -> Entrez l'ID exact du modèle depuis '{json_filename}' (ou 's' pour sauter) : ").strip()

            if not manual_id or manual_id.lower() == 's':
                print("    Mise à jour JSON sautée par l'utilisateur.")
                return False

            # Recherche à nouveau avec l'ID fourni manuellement
            for model in data['models']:
                if model.get('id') == manual_id:
                    model_to_update = model
                    break
            
            if not model_to_update:
                print(f"❌ L'ID '{manual_id}' que vous avez entré n'a pas été trouvé. La mise à jour JSON est annulée.")
                return False
        
        # Si on a trouvé un modèle (d'une manière ou d'une autre), on met à jour
        original_id = model_to_update['id']
        print(f"📝 Correspondance trouvée ! Mise à jour de l'URL pour l'ID '{original_id}' dans '{json_filename}'...")
        model_to_update['imageUrl'] = new_image_url
            
        with open(json_filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Fichier JSON mis à jour.")
        return True

    except Exception as e:
        print(f"❌ Erreur critique lors de la mise à jour du fichier JSON : {e}")
        return False

def process_broken_images_interactively(broken_files, json_folder, firebase_bucket, all_brands):
    if not broken_files:
        print("\n🎉 Aucune image corrompue ou invalide n'a été trouvée !")
        return
    print(f"\n🚨 {len(broken_files)} image(s) à réparer. Début du processus de remplacement. 🚨")
    
    for i, filepath in enumerate(broken_files):
        filename = os.path.basename(filepath)
        print("\n" + "="*60)
        print(f"--- Réparation de l'image n°{i+1}/{len(broken_files)} : {filename} ---")

        filename_base = os.path.splitext(filename)[0]
        search_query = filename_base.replace('_', ' ').replace('-', ' ')
        
        if PYPERCLIP_AVAILABLE:
            try:
                pyperclip.copy(search_query)
                print(f"✅ Nom '{search_query}' copié dans le presse-papiers.")
            except pyperclip.PyperclipException: pass

        while True:
            choice = input("Entrez l'URL de la nouvelle image ('s' pour sauter, 'q' pour quitter) > ").strip()
            if choice.lower() == 'q': return
            if choice.lower() == 's': break
            if not choice.startswith('http'):
                print("URL invalide. Veuillez recommencer.")
                continue

            print(f"🔄 Remplacement de '{filename}'...")
            if not download_image(choice, filepath): continue
            new_firebase_url = upload_to_firebase(filepath, firebase_bucket)
            if not new_firebase_url: break

            found_brand = next((b for b in all_brands if filename_base.lower().startswith(b.lower())), None)
            if not found_brand:
                print(f"❌ Impossible de déterminer la marque pour '{filename}'. Annulation de la mise à jour JSON.")
                break

            clean_filename_base = filename_base
            for separator in ['_', '-']:
                redundant_prefix = f"{found_brand}{separator}{found_brand}{separator}"
                if clean_filename_base.lower().startswith(redundant_prefix):
                    clean_filename_base = clean_filename_base[len(found_brand)+1:]
                    break
            
            json_updated = update_json_file(clean_filename_base, new_firebase_url, json_folder, found_brand)
            
            if json_updated:
                 print(f"\n🎉 Remplacement complet pour '{filename}' terminé avec succès! 🎉")
            else:
                 print(f"\n⚠️ Remplacement partiel pour '{filename}'. L'image a été changée, mais pas le JSON.")
            break

if __name__ == "__main__":
    # --- CHEMINS À CONFIGURER ---
    # Le dossier contenant toutes vos images (y compris les corrompues)
    SOURCE_FOLDER = r"C:\Users\owenm\Downloads\modeles_image"
    # Le dossier contenant vos fichiers JSON
    JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
    # Le chemin vers votre clé de service Firebase
    FIREBASE_CREDENTIALS_PATH = r"C:\Users\owenm\Documents\spot_my_car\car-spotter-app-779f2-firebase-adminsdk-fbsvc-4a7d0bed3f.json"
    FIREBASE_BUCKET_NAME = "car-spotter-app-779f2.firebasestorage.app"
 
    print("="*60)
    print("Lancement de l'outil de réparation d'images manquantes")
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

    broken_image_list = find_broken_images(SOURCE_FOLDER)
    process_broken_images_interactively(
        broken_image_list,
        JSON_MODELS_FOLDER,
        bucket,
        all_brands
    )
    
    print("\nOpération terminée.")
