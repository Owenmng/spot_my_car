# Fichier: reset_urls.py
import os
import json
from urllib.parse import unquote

MODELS_JSON_DIRECTORY = "assets/data/models_by_brand"

def reset_json_files():
    print(f"--- Lancement de la réinitialisation des URLs ---")
    try:
        json_files = [f for f in os.listdir(MODELS_JSON_DIRECTORY) if f.endswith('.json')]
        for filename in json_files:
            file_path = os.path.join(MODELS_JSON_DIRECTORY, filename)
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            if 'models' in data:
                for model in data['models']:
                    url = model.get('imageUrl')
                    if url and url.startswith('http'):
                        # On extrait le nom du fichier de l'URL
                        file_name = unquote(url.split('%2F')[-1].split('?')[0])
                        model['imageUrl'] = file_name

                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"  - Réinitialisé : {filename}")

        print("\n--- Réinitialisation terminée ! ---")
    except Exception as e:
        print(f"Erreur : {e}")

if __name__ == "__main__":
    reset_json_files()