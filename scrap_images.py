#!/usr/bin/env python3
# --- VERSION HYBRIDE : AUTO + INTERVENTION MANUELLE ---

import os
import json
import time
import requests
from selenium import webdriver
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, storage
import urllib.parse
import shutil

class ReportProcessor:
    # ... (Aucun changement dans cette classe)
    def __init__(self, report_filepath):
        self.report_filepath = report_filepath

    def get_models_to_fix(self):
        if not os.path.exists(self.report_filepath):
            print(f"❌ Erreur: Le fichier rapport '{self.report_filepath}' n'a pas été trouvé.")
            return None
        models_to_fix = {}
        print(f"Lecture du fichier rapport : {self.report_filepath}")
        with open(self.report_filepath, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or ' - ' not in line: continue
                try:
                    brand_name, model_name, model_id = [part.strip() for part in line.split(' - ')]
                    brand_key = brand_name.lower().replace(' ', '_')
                    if brand_key not in models_to_fix: models_to_fix[brand_key] = []
                    models_to_fix[brand_key].append(model_id)
                except ValueError:
                    print(f"  -> Ligne ignorée (format incorrect) : '{line}'")
        if not models_to_fix:
            print("Le fichier rapport est vide ou ne contient aucun modèle valide à traiter.")
            return None
        print(f"Trouvé {sum(len(ids) for ids in models_to_fix.values())} modèles à corriger dans {len(models_to_fix)} marques.")
        return models_to_fix


class CarImageDownloader:
    def __init__(self):
        self.download_folder = r"C:\Users\owenm\Downloads\modeles_image"
        self.json_folder = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
        self.firebase_key = r"C:\Users\owenm\Documents\spot_my_car\serviceAccountKey.json"
        os.makedirs(self.download_folder, exist_ok=True)
        self.init_firebase()
        self.stats = {'success': 0, 'errors': 0, 'skipped': 0, 'processed': 0}

    def init_firebase(self):
        # ... (Aucun changement)
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(self.firebase_key)
                firebase_admin.initialize_app(cred, {'storageBucket': 'car-spotter-app-779f2.firebasestorage.app'})
            self.bucket = storage.bucket()
        except Exception as e:
            print(f"❌ Erreur Firebase: {e}")
            raise

    def setup_driver(self):
        # ... (Aucun changement)
        options = Options()
        options.add_argument('--headless=new')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument("log-level=3")
        options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36')
        options.add_experimental_option('excludeSwitches', ['enable-logging'])
        service = Service(ChromeDriverManager().install())
        return webdriver.Chrome(service=service, options=options)

    # --- NOUVEAU : Fonction helper pour le traitement de l'image (téléchargement, upload, JSON) ---
    def _handle_image_processing(self, img_url, model_id, json_file_path):
        """Prend une URL et effectue toutes les opérations. Retourne True si succès, False si échec."""
        try:
            headers = {'User-Agent': 'Mozilla/5.0'}
            filepath = os.path.join(self.download_folder, f"{model_id}.jpg")
            
            # 1. Télécharger l'image
            print(f"  -> Téléchargement depuis : {img_url[:80]}...")
            with requests.get(img_url, stream=True, timeout=15, headers=headers) as r, open(filepath, 'wb') as f:
                r.raise_for_status()
                shutil.copyfileobj(r.raw, f)

            # 2. Upload sur Firebase
            print("  -> Upload sur Firebase...")
            blob = self.bucket.blob(f"models/{model_id}.jpg")
            blob.upload_from_filename(filepath, content_type='image/jpeg')
            blob.make_public()
            firebase_url = blob.public_url

            # 3. Mettre à jour le fichier JSON
            print("  -> Mise à jour du fichier JSON...")
            with open(json_file_path, 'r+', encoding='utf-8') as f:
                data = json.load(f)
                for m in data['models']:
                    if m['id'] == model_id:
                        m['imageUrl'] = firebase_url
                        break
                f.seek(0)
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.truncate()
            
            return True # Succès

        except Exception as e:
            print(f"  -> ❌ Échec du traitement de l'URL : {e}")
            return False # Échec

    # --- MODIFIÉ : La fonction principale intègre maintenant l'invite manuelle ---
    def process_model(self, brand, model_data, json_file_path):
        model_id = model_data['id']
        model_name = model_data['name']
        year = model_data.get('production_years', '').split(' - ')[0] if model_data.get('production_years') else ''
        self.stats['processed'] += 1
        
        query = f"{brand} {model_name} {year} photo officielle"
        print(f"\n--- Traitement de : {brand} {model_name} ({year}) ---")
        
        # Étape 1 : Tentative Automatique
        download_success = False
        driver = None
        try:
            driver = self.setup_driver()
            if not driver: raise Exception("Le driver n'a pas pu être initialisé.")
            
            print(f"-> Recherche automatique de '{query}'...")
            driver.get(f"https://www.bing.com/images/search?q={urllib.parse.quote_plus(query)}&first=1")
            
            wait = WebDriverWait(driver, 10)
            image_links = wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, "a.iusc")))

            for i, link in enumerate(image_links[:5]):
                print(f"  -> Tentative automatique #{i+1}...")
                metadata = json.loads(link.get_attribute('m'))
                img_url = metadata.get('murl')
                if self._handle_image_processing(img_url, model_id, json_file_path):
                    download_success = True
                    break # On a réussi, on sort de la boucle
        
        except (WebDriverException, TimeoutException) as e:
            print(f"  -> L'automatisation a échoué (Erreur Selenium: {type(e).__name__}).")
        except Exception as e:
            print(f"  -> L'automatisation a échoué (Erreur inattendue: {e}).")
        finally:
            if driver: driver.quit()

        # Étape 2 : Intervention Manuelle si l'étape 1 a échoué
        if not download_success:
            print("\n" + "="*20)
            print(f"⚠️ L'AUTOMATISATION A ÉCHOUÉ POUR : {brand} {model_name}")
            print("="*20)
            manual_url = input("Veuillez coller une URL d'image valide ou appuyez sur [Entrée] pour ignorer : ").strip()

            if manual_url and manual_url.startswith('http'):
                if self._handle_image_processing(manual_url, model_id, json_file_path):
                    download_success = True # On marque le succès
            else:
                print("-> Modèle ignoré par l'utilisateur.")
                self.stats['skipped'] += 1

        # Étape 3 : Bilan pour ce modèle
        if download_success:
            print(f"✅ SUCCÈS pour {brand} {model_name}")
            self.stats['success'] += 1
        else:
            print(f"❌ ÉCHEC FINAL pour {brand} {model_name}")
            self.stats['errors'] += 1

    def process_failures_from_report(self, models_to_fix):
        # ... La logique de cette fonction reste la même, elle appelle juste la nouvelle `process_model`
        print("\nDébut de la correction des échecs...\n")
        
        for brand_key, model_ids_to_fix in models_to_fix.items():
            brand_display_name = brand_key.replace('_', ' ').title()
            json_filename = f"{brand_key}.json"
            json_file_path = os.path.join(self.json_folder, json_filename)

            if not os.path.exists(json_file_path):
                print(f"⚠️ Fichier JSON pour la marque '{brand_display_name}' non trouvé. Ignoré.")
                self.stats['errors'] += len(model_ids_to_fix)
                continue
            
            try:
                with open(json_file_path, 'r', encoding='utf-8') as f: data = json.load(f)
                models_in_file = {m['id']: m for m in data['models']}

                for model_id in model_ids_to_fix:
                    if model_id in models_in_file:
                        model_to_process = models_in_file[model_id]
                        self.process_model(brand_display_name, model_to_process, json_file_path)
                        time.sleep(1)
                    else:
                        print(f"❌ Erreur: Modèle avec ID '{model_id}' non trouvé dans '{json_filename}'.")
                        self.stats['errors'] += 1
            except Exception as e:
                print(f"Une erreur inattendue est survenue pour la marque {brand_display_name}: {e}")


        print("\n" + "="*50)
        print("Correction terminée.")
        print(f"Bilan final: {self.stats['success']} succès, {self.stats['errors']} échecs, {self.stats['skipped']} ignorés sur {self.stats['processed']} modèles traités.")
        print("="*50)

def main():
    REPORT_FILE = "echecs_images.txt"
    try:
        report_processor = ReportProcessor(REPORT_FILE)
        models_to_fix = report_processor.get_models_to_fix()
        if models_to_fix:
            downloader = CarImageDownloader()
            downloader.process_failures_from_report(models_to_fix)
        else:
            print("\n🎉 Aucune action requise. Le rapport est vide ou non trouvé.")
    except Exception as e:
        print(f"ERREUR CRITIQUE DANS LE PROCESSUS GLOBAL: {e}")

if __name__ == "__main__":
    main()