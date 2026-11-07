    #!/usr/bin/env python3
"""
Vide toutes les URLs d'images des fichiers JSON
"""

import os
import json

def reset_json_files(json_folder):
    for filename in os.listdir(json_folder):
        if filename.endswith('.json'):
            filepath = os.path.join(json_folder, filename)
            
            with open(filepath, 'r+', encoding='utf-8') as f:
                data = json.load(f)
                updated = False
                
                for model in data['models']:
                    if 'imageUrl' in model:
                        model['imageUrl'] = ""
                        updated = True
                
                if updated:
                    f.seek(0)
                    json.dump(data, f, indent=2, ensure_ascii=False)
                    f.truncate()
                    print(f"✅ Réinitialisé: {filename}")

if __name__ == "__main__":
    json_folder = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
    print("Début de la réinitialisation des URLs...")
    reset_json_files(json_folder)
    print("\nOpération terminée")