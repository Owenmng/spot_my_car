# --- fix_images_manually.py (Version 2.4 - Essais Multiples) ---
import os
import json
import time
import requests
import firebase_admin
from firebase_admin import credentials, storage
from tqdm import tqdm
import shutil
import pyperclip
from thefuzz import process

# ==============================================================================
# --- CONFIGURATION ---
# ==============================================================================
DOWNLOAD_FOLDER = r"C:\Users\owenm\Downloads\modeles_image_temp_fix"
JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
FIREBASE_KEY_PATH = r"C:\Users\owenm\Documents\spot_my_car\serviceAccountKey.json"
BUCKET_NAME = "car-spotter-app-779f2.firebasestorage.app"
FIREBASE_MODELS_FOLDER = "models"
SIMILARITY_THRESHOLD = 85 

MODELS_TO_FIX = {
    'cadillac' : ['chiron', 'chiron super sport', 'eb 110 ss', 'eb 112', 'la voiture noire', 'type 252', 'type 35', 'type 35b', 'type 37a', 'type 41 royale', 'type 50', 'type 57 Gangloff', 'type 57s', 'type 73c', 'veyron 16.4', 'veyron vitesse'] 
    }

class ManualImageFixer:
    def __init__(self):
        os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)
        self.init_firebase()
        self.stats = {'success': 0, 'errors': 0, 'skipped': 0, 'processed': 0}

    def init_firebase(self):
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(FIREBASE_KEY_PATH)
                firebase_admin.initialize_app(cred, {'storageBucket': BUCKET_NAME})
            self.bucket = storage.bucket()
            print("✅ Connexion à Firebase réussie.")
        except Exception as e:
            print(f"❌ ERREUR FATALE Firebase: {e}")
            raise

    def find_all_models_in_json(self, brand_key):
        json_path = os.path.join(JSON_MODELS_FOLDER, f"{brand_key}.json")
        if not os.path.exists(json_path): return None, None, None
        with open(json_path, 'r', encoding='utf-8') as f: data = json.load(f)
        models_list, list_key = None, None
        for key, value in data.items():
            if isinstance(value, list):
                models_list, list_key = value, key
                break
        return models_list, json_path, list_key

    def handle_image_processing(self, img_url, model_id, json_file_path, list_key):
        try:
            headers = {'User-Agent': 'Mozilla/5.0'}
            filepath = os.path.join(DOWNLOAD_FOLDER, f"{model_id}.jpg")
            print(f"  -> 📥 Tentative de téléchargement depuis : {img_url[:80]}...")
            with requests.get(img_url, stream=True, timeout=20, headers=headers) as r, open(filepath, 'wb') as f:
                r.raise_for_status() # Lève une erreur si le code HTTP n'est pas 200 (ex: 404 Not Found)
                shutil.copyfileobj(r.raw, f)
            print("  -> 📤 Upload sur Firebase...")
            remote_path = f"{FIREBASE_MODELS_FOLDER}/{model_id}.jpg"
            blob = self.bucket.blob(remote_path)
            blob.upload_from_filename(filepath, content_type='image/jpeg')
            blob.make_public()
            firebase_url = blob.public_url
            print("  -> 📝 Mise à jour du fichier JSON...")
            with open(json_file_path, 'r+', encoding='utf-8') as f:
                data = json.load(f)
                model_found = False
                for m in data[list_key]:
                    if m['id'] == model_id:
                        m['imageUrl'] = firebase_url
                        model_found = True
                        break
                if not model_found: raise Exception(f"L'ID '{model_id}' non trouvé dans le JSON.")
                f.seek(0); json.dump(data, f, indent=2, ensure_ascii=False); f.truncate()
            return True
        except requests.exceptions.RequestException as e:
            # Erreur plus spécifique pour les problèmes réseau ou URL
            print(f"  -> ❌ Échec du téléchargement : {e}")
            return False
        except Exception as e:
            print(f"  -> ❌ Échec du traitement de l'URL : {e}")
            return False

    def run(self, models_to_process):
        print("\n" + "="*50)
        print("🚀 Démarrage du processus de correction manuelle d'images 🚀")
        print("="*50 + "\n")

        total_models = sum(len(names) for names in models_to_process.values())
        progress_bar = tqdm(total=total_models, desc="Progression globale")

        for brand_key, model_names_to_search in models_to_process.items():
            brand_display_name = brand_key.replace('-', ' ').title()
            all_models_in_brand, json_path, list_key = self.find_all_models_in_json(brand_key)

            if not all_models_in_brand:
                print(f"⚠️ Fichier JSON pour '{brand_key}' non trouvé ou vide. {len(model_names_to_search)} modèles ignorés.")
                self.stats['errors'] += len(model_names_to_search); progress_bar.update(len(model_names_to_search)); continue

            for search_term in model_names_to_search:
                self.stats['processed'] += 1
                progress_bar.set_description(f"Marque: {brand_display_name}")
                print(f"\n--- Recherche de : '{search_term.title()}' dans la marque '{brand_display_name}' ---")
                
                normalized_search = search_term.lower().strip()
                matches = [model for model in all_models_in_brand if normalized_search in model.get('name', '').lower().strip()]
                
                if not matches:
                    print("  -> Pas de correspondance directe. Lancement de la recherche par similarité...")
                    all_model_names = {m.get('name'): m for m in all_models_in_brand}
                    fuzzy_results = process.extractBests(search_term, all_model_names.keys(), score_cutoff=SIMILARITY_THRESHOLD, limit=5)
                    if fuzzy_results:
                        print("  -> 🤔 Suggestions trouvées :"); matches = [all_model_names[name] for name, score in fuzzy_results]
                    else: matches = []

                if not matches:
                    print(f"❌ AUCUNE CORRESPONDANCE TROUVÉE pour '{search_term}' dans {brand_key}.json")
                    self.stats['errors'] += 1; progress_bar.update(1); continue
                
                chosen_model = None
                if len(matches) == 1:
                    chosen_model = matches[0]; print(f"  -> Correspondance trouvée : '{chosen_model.get('name')}'")
                else:
                    print(f"  -> Plusieurs correspondances trouvées. Veuillez choisir :")
                    for i, match in enumerate(matches): print(f"    {i+1}: {match.get('name')}")
                    while True:
                        try:
                            choice = input("  -> Votre choix (numéro) ou 0 pour ignorer tous : "); choice_int = int(choice)
                            if choice_int == 0: chosen_model = None; break
                            if 1 <= choice_int <= len(matches): chosen_model = matches[choice_int - 1]; break
                            else: print("    /!\\ Choix invalide.")
                        except ValueError: print("    /!\\ Veuillez entrer un nombre.")
                
                if not chosen_model:
                    print("-> ⏩ Groupe ignoré."); self.stats['skipped'] += 1; progress_bar.update(1); continue

                model_id = chosen_model.get('id'); model_name = chosen_model.get('name')
                year = chosen_model.get('production_years', '').split(' - ')[0] if chosen_model.get('production_years') else ''
                search_suggestion = f"{brand_display_name} {model_name} {year}"
                pyperclip.copy(search_suggestion)
                
                print("\n" + "-"*20); print(f"Prêt à modifier le modèle : '{model_name}'")
                print(f"💡 Suggestion de recherche : {search_suggestion}"); print("   (Copiée dans le presse-papiers !)")
                
                # ==========================================================
                # === NOUVELLE BOUCLE DE SAISIE AVEC ESSAIS MULTIPLES ======
                # ==========================================================
                while True:
                    manual_url = input("🔗 Collez une URL d'image valide ou appuyez sur [Entrée] pour ignorer : ").strip()

                    # CAS 1 : L'utilisateur veut ignorer
                    if not manual_url:
                        print("-> ⏩ Modèle ignoré par l'utilisateur.")
                        self.stats['skipped'] += 1
                        break # Sort de la boucle de saisie

                    # CAS 2 : L'utilisateur entre une URL valide et le traitement réussit
                    if self.handle_image_processing(manual_url, model_id, json_path, list_key):
                        print(f"✅ SUCCÈS pour {brand_display_name} {model_name}")
                        self.stats['success'] += 1
                        break # Sort de la boucle de saisie
                    
                    # CAS 3 : L'URL est mauvaise ou le traitement échoue
                    else:
                        print("   /!\\ Le lien n'a pas fonctionné. Veuillez trouver et coller une autre URL.")
                        # La boucle continue, on redemande une URL.
                
                progress_bar.update(1); time.sleep(0.5)

        progress_bar.close()
        print("\n" + "="*50); print("🏁 Correction terminée. 🏁")
        print(f"Bilan final: {self.stats['success']} succès, {self.stats['errors']} échecs, {self.stats['skipped']} ignorés sur {self.stats['processed']} modèles traités.")
        print("="*50)

if __name__ == "__main__":
    try:
        fixer = ManualImageFixer()
        fixer.run(MODELS_TO_FIX)
    except Exception as e:
        print(f"\n\n🚨 ERREUR CRITIQUE INATTENDUE - LE SCRIPT S'EST ARRÊTÉ 🚨"); print(e)