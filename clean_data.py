import os
import json

def clean_json_file(file_path, keys_to_clean):
    """
    Ouvre un fichier JSON, nettoie les chemins dans les clés spécifiées,
    et réécrit le fichier.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Détermine si on doit itérer sur une liste de dictionnaires
        # ou un seul dictionnaire.
        # Ex: 'brands' dans brands.json, 'models' dans les fichiers de modèles.
        data_list_key = next((key for key in data if isinstance(data[key], list)), None)

        if data_list_key:
            items_to_process = data[data_list_key]
        elif isinstance(data, list):
            items_to_process = data
        else:
            items_to_process = [data] # Si c'est un seul objet, on le met dans une liste

        modified = False
        for item in items_to_process:
            for key in keys_to_clean:
                if key in item and isinstance(item[key], str):
                    # Ne modifie que si le chemin est présent
                    if 'assets/' in item[key]:
                        # Extrait juste le nom du fichier
                        item[key] = os.path.basename(item[key])
                        modified = True
        
        # Réécrit le fichier seulement s'il a été modifié
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                # indent=2 pour garder le fichier lisible, ensure_ascii=False pour les accents
                json.dump(data, f, indent=2, ensure_ascii=False)
            print(f"  -> Fichier nettoyé : {file_path}")
        else:
            print(f"  -> Fichier déjà propre : {file_path}")

    except FileNotFoundError:
        print(f"  [ERREUR] Fichier non trouvé : {file_path}")
    except json.JSONDecodeError:
        print(f"  [ERREUR] Format JSON invalide dans : {file_path}")
    except Exception as e:
        print(f"  [ERREUR] Erreur inconnue pour le fichier {file_path}: {e}")


def main():
    """
    Fonction principale qui orchestre le nettoyage.
    """
    # Chemin vers le dossier de données, relatif à la racine du projet
    data_path = os.path.join('assets', 'data')

    # --- Étape 1 : Nettoyer le fichier des marques ---
    brands_file = os.path.join(data_path, 'brands.json')
    print("\nNettoyage du fichier des marques...")
    clean_json_file(brands_file, ['logoUrl'])

    # --- Étape 2 : Nettoyer tous les fichiers de modèles ---
    models_path = os.path.join(data_path, 'models_by_brand')
    print("\nNettoyage des fichiers de modèles...")
    
    if os.path.exists(models_path):
        for filename in os.listdir(models_path):
            if filename.endswith('.json'):
                model_file = os.path.join(models_path, filename)
                clean_json_file(model_file, ['imageUrl'])
    else:
        print(f"  [AVERTISSEMENT] Dossier non trouvé : {models_path}")

    print("\n--- Nettoyage terminé ! ---")


# Lance la fonction principale si le script est exécuté directement
if __name__ == "__main__":
    main()