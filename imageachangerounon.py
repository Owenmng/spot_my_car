import os
import json
import time
import requests
import firebase_admin
from firebase_admin import credentials, storage
from tqdm import tqdm
import shutil
import pyperclip
from collections import defaultdict
import msvcrt

# ==============================================================================
# --- CONFIGURATION ---
# ==============================================================================
DOWNLOAD_FOLDER = r"C:\Users\owenm\Downloads\modeles_image_temp_fix"
JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
FIREBASE_KEY_PATH = r"C:\Users\owenm\Documents\spot_my_car\serviceAccountKey.json"
BUCKET_NAME = "car-spotter-app-779f2.firebasestorage.app"
FIREBASE_MODELS_FOLDER = "models"
START_FROM_FILE = 'cadillac.json'

# --- CODES POUR LE TEXTE EN GRAS ---
BOLD = '\033[1m'
END = '\033[0m'
# ==============================================================================

class LiveImageFixer:
    def __init__(self):
        os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)
        self.init_firebase()
        self.stats = {'success': 0, 'skipped': 0, 'total_checked': 0}

    def init_firebase(self):
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(FIREBASE_KEY_PATH)
                firebase_admin.initialize_app(cred, {'storageBucket': BUCKET_NAME})
            self.bucket = storage.bucket()
            print("✅ Connexion à Firebase réussie.")
        except Exception as e:
            print(f"❌ ERREUR FATALE Firebase: {e}"); raise

    def handle_image_replacement(self, new_img_url, model_id, brand_key):
        json_file_path = os.path.join(JSON_MODELS_FOLDER, f"{brand_key}.json")
        try:
            headers = {'User-Agent': 'Mozilla/5.0'}
            file_extension = os.path.splitext(new_img_url.split('?')[0])[-1] or '.jpg'
            filepath = os.path.join(DOWNLOAD_FOLDER, f"{model_id}{file_extension}")
            print(f"  -> 📥 Téléchargement...")
            with requests.get(new_img_url, stream=True, timeout=20, headers=headers) as r, open(filepath, 'wb') as f:
                r.raise_for_status()
                shutil.copyfileobj(r.raw, f)
            
            print("  -> 📤 Upload sur Firebase...")
            remote_path = f"{FIREBASE_MODELS_FOLDER}/{model_id}{file_extension}"
            blob = self.bucket.blob(remote_path)
            blob.upload_from_filename(filepath, content_type=f'image/{file_extension.strip(".")}')
            blob.make_public()
            firebase_url = blob.public_url
            
            print("  -> 📝 Mise à jour du JSON...")
            with open(json_file_path, 'r+', encoding='utf-8') as f:
                data = json.load(f)
                model_found = False
                for m in data['models']:
                    if m['id'] == model_id:
                        m['imageUrl'] = firebase_url
                        model_found = True
                        break
                if not model_found: raise Exception("ID non trouvé")
                f.seek(0); json.dump(data, f, indent=2, ensure_ascii=False); f.truncate()
            return True
        except Exception as e:
            print(f"  -> ❌ ÉCHEC du remplacement : {e}")
            return False

    def trigger_fix_process(self, brand_key, model):
        model_id = model.get('id'); model_name = model.get('name')
        year = model.get('production_years', '').split(' - ')[0] if model.get('production_years') else ''
        search_suggestion = f"{brand_key.replace('.json', '').replace('-', ' ').title()} {model_name} {year}"
        pyperclip.copy(search_suggestion)
        
        print("\n" + "-"*20); print(f"-> Correction pour : '{model_name}'")
        print(f"-> Suggestion : {search_suggestion} (copiée !)")
        
        while True:
            manual_url = input("🔗 Collez une URL ou [Entrée] pour ignorer : ").strip()
            if not manual_url:
                print("-> ⏩ Modèle ignoré.")
                self.stats['skipped'] += 1
                return
            
            if self.handle_image_replacement(manual_url, model_id, brand_key):
                print(f"✅ SUCCÈS pour {model_name}")
                self.stats['success'] += 1
                return
            else:
                print("   /!\\ Le lien n'a pas fonctionné. Essayez une autre URL.")

def get_single_key():
    return msvcrt.getch().decode('utf-8').lower()

if __name__ == "__main__":
    try:
        fixer = LiveImageFixer()
    except Exception:
        exit()

    json_files = sorted([f for f in os.listdir(JSON_MODELS_FOLDER) if f.endswith('.json')])
    if START_FROM_FILE:
        try:
            start_index = json_files.index(START_FROM_FILE)
            json_files = json_files[start_index:]
            print(f"\nAudit configuré pour commencer à : {START_FROM_FILE}")
        except ValueError:
            print(f"🚨 Fichier de départ '{START_FROM_FILE}' non trouvé. L'audit commencera au début.")

    print("="*60); print("🚀 Lancement de l'audit et correction en direct 🚀")
    print("Appuyez sur 'y' (OK), 'n' (NON, corriger), 'q' (quitter). Pas besoin d'Entrée.")
    print("="*60)
    
    try:
        for json_file in json_files:
            brand_id = os.path.splitext(json_file)[0]
            file_path = os.path.join(JSON_MODELS_FOLDER, json_file)
            
            with open(file_path, 'r', encoding='utf-8') as f: data = json.load(f)
            
            models = data.get('models', [])
            
            for model in tqdm(models, desc=f"Marque: {brand_id.title()}", unit=" modèle"):
                fixer.stats['total_checked'] += 1
                model_id = model.get('id')
                model_name = model.get('name', 'Nom inconnu')
                if not model_id: continue
                
                print(f"\n\nModèle : {BOLD}{brand_id.title()} - {model_name}{END}")
                print(f"URL actuelle: {model.get('imageUrl', 'N/A')[:100]}")
                print("L'image vous convient-elle ? (y/n/q) ", end="", flush=True)

                while True:
                    key = get_single_key()
                    if key == 'y':
                        print("OUI"); break
                    elif key == 'n':
                        print("NON -> Correction")
                        fixer.trigger_fix_process(brand_id, model)
                        break
                    elif key == 'q':
                        print("QUITTER"); raise KeyboardInterrupt
    
    except KeyboardInterrupt:
        print("\n\nInterruption par l'utilisateur.")
    
    finally:
        print("\n" + "="*50); print("🏁 Audit terminé. 🏁")
        stats = fixer.stats
        print(f"Bilan: {stats['success']} corrigés, {stats['skipped']} ignorés sur {stats['total_checked']} modèles vérifiés.")
        print("="*50)