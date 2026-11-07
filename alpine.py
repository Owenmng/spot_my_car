# Fichier: scrape_model_list.py

import requests
from bs4 import BeautifulSoup
import json
import re
import os

# ==============================================================================
# ===   CONFIGURATIONS (Tu peux changer l'URL pour une autre marque)     ===
# ==============================================================================

BRAND_URL = "https://www.auto-data.net/en/alpine-brand-21"
BRAND_NAME = BRAND_URL.split('/')[-1].split('-brand-')[0]
OUTPUT_FILENAME = f"assets/data/models_by_brand/{BRAND_NAME}.json"
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

# ==============================================================================
# ===            LE SCRIPT DE SCRAPING (Fait ce que tu as demandé)        ===
# ==============================================================================

def generate_id(brand_name, model_name):
    """Génère un ID unique et propre pour un modèle."""
    s = re.sub(r'[^\w\s-]', '', model_name.lower())
    s = re.sub(r'[-\s]+', '_', s).strip('_')
    return f"{brand_name}_{s}"

def main():
    """Fonction principale du script."""
    print(f"--- Lancement du scraping de la liste de modèles pour '{BRAND_NAME}' ---")
    
    try:
        print(f"[*] Récupération des informations depuis {BRAND_URL}...")
        response = requests.get(BRAND_URL, headers=HEADERS)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        # On cherche le conteneur principal de la liste des modèles
        model_list_container = soup.find('ul', class_='modelite')
        if not model_list_container:
            print("[!!!] ERREUR: Impossible de trouver la liste des modèles. La structure du site a peut-être changé.")
            return

        final_models_list = []
        
        # On boucle sur chaque "carte" de modèle trouvée
        for model_card in model_list_container.find_all('a', class_='modeli'):
            
            # Extraction du nom du modèle
            model_name_tag = model_card.find('strong')
            if not model_name_tag:
                continue
            model_name = model_name_tag.text.strip()

            # Extraction des années de production
            production_years = "Non spécifié"
            years_tag = model_card.find('div', class_=re.compile("color$")) # Trouve la div qui finit par "color"
            if years_tag:
                production_years = years_tag.text.strip()

            # Création de l'objet modèle
            model_data = {
                "id": generate_id(BRAND_NAME, model_name),
                "name": model_name,
                "imageUrl": "", # Laissé vide comme demandé
                "production_years": production_years,
                # On met les autres champs à null car ils ne sont pas sur cette page
                "puissance_ch": None,
                "vitesse_max_kmh": None,
                "zero_a_cent_s": None,
                "type_carburant": None,
                "consommation_mixte": None,
                "dimensions_lwh_mm": None,
                "poids_kg": None,
                "prix_lancement_eur": None
            }
            final_models_list.append(model_data)
            print(f"  - Trouvé : {model_name} ({production_years})")

        # Sauvegarde du fichier JSON
        if final_models_list:
            final_json_object = {"models": final_models_list}
            os.makedirs(os.path.dirname(OUTPUT_FILENAME), exist_ok=True)
            
            with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
                json.dump(final_json_object, f, ensure_ascii=False, indent=2)
            
            print(f"\n--- Scraping terminé avec succès ! ---")
            print(f"{len(final_models_list)} modèles ont été sauvegardés dans '{OUTPUT_FILENAME}'")
        else:
            print("\n[!] Aucun modèle n'a pu être trouvé sur la page.")

    except Exception as e:
        print(f"\n[!!!] UNE ERREUR EST SURVENUE: {e}")

if __name__ == "__main__":
    main()