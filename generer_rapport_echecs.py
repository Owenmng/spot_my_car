import os
import json

def find_failed_models(json_folder):
    """
    Parcourt un dossier de fichiers JSON, identifie les modèles avec une
    imageUrl vide et retourne une liste formatée (Marque - Modèle - ID) de ces modèles.
    """
    if not os.path.isdir(json_folder):
        print(f"Erreur: Le dossier source '{json_folder}' n'existe pas.")
        return None

    failed_list = []
    
    print(f"Analyse des fichiers JSON dans : {json_folder}")
    
    # Parcourir tous les fichiers du dossier
    for filename in sorted(os.listdir(json_folder)):
        if filename.lower().endswith('.json'):
            # Extraire le nom de la marque à partir du nom du fichier
            # ex: 'alfa_romeo.json' -> 'Alfa Romeo'
            brand_name = filename.replace('.json', '').replace('_', ' ').title()
            
            file_path = os.path.join(json_folder, filename)
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                # Vérifier chaque modèle dans le fichier
                # Utiliser .get('models', []) pour éviter une erreur si la clé 'models' n'existe pas
                for model in data.get('models', []):
                    # La condition d'échec :
                    # 1. La clé 'imageUrl' n'existe pas
                    # 2. La clé 'imageUrl' existe mais sa valeur est vide ("") ou None
                    # La méthode .get() gère élégamment ces cas.
                    if not model.get('imageUrl'):
                        model_name = model.get('name', 'NOM DE MODÈLE MANQUANT')
                        
                        # --- NOUVEAU : Récupérer l'ID du modèle ---
                        # On utilise .get() pour éviter une erreur si la clé 'id' est absente
                        model_id = model.get('id', 'ID MANQUANT')
                        
                        # --- MODIFIÉ : Ajouter l'ID à la chaîne de caractères ---
                        failed_list.append(f"{brand_name} - {model_name} - {model_id}")

            except json.JSONDecodeError:
                print(f"  Attention: Le fichier '{filename}' est malformé et a été ignoré.")
            except Exception as e:
                print(f"  Erreur inattendue en traitant '{filename}': {e}")
                
    return failed_list

def write_report(failed_models, output_filepath):
    """
    Écrit la liste des modèles en échec dans un fichier de rapport.
    """
    print(f"\nÉcriture du rapport dans le fichier : {output_filepath}")
    
    try:
        with open(output_filepath, 'w', encoding='utf-8') as f:
            if not failed_models:
                f.write("🎉 Bonne nouvelle ! Aucun modèle en échec n'a été trouvé.\n")
                f.write("Toutes les images semblent avoir été récupérées avec succès.\n")
            else:
                f.write(f"Rapport des {len(failed_models)} modèles dont l'image est manquante :\n")
                f.write("=" * 60 + "\n\n")
                for item in failed_models:
                    f.write(item + "\n")
        
        print("\n✅ Rapport généré avec succès !")
        if failed_models:
            print(f"Vous pouvez consulter la liste des {len(failed_models)} modèles dans le fichier '{output_filepath}'.")
        else:
            print("Aucun échec à signaler.")

    except IOError as e:
        print(f"\n❌ Erreur: Impossible d'écrire dans le fichier '{output_filepath}': {e}")


if __name__ == "__main__":
    # --- CHEMINS À VÉRIFIER ---
    # Le dossier contenant tous vos fichiers JSON de modèles par marque
    JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
    # Le fichier de sortie qui contiendra la liste des échecs
    OUTPUT_REPORT_FILE = "echecs_images.txt"
    
    # Lancement du processus
    failures = find_failed_models(JSON_MODELS_FOLDER)
    
    if failures is not None:
        write_report(failures, OUTPUT_REPORT_FILE)