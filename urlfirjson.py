import os
import json
import firebase_admin
from firebase_admin import credentials, storage

def get_all_json_image_urls(json_folder):
    """
    Parcourt tous les fichiers JSON et collecte les 'imageUrl' valides.
    """
    if not os.path.isdir(json_folder):
        print(f"❌ Erreur: Le dossier JSON '{json_folder}' n'existe pas.")
        return None

    valid_urls = set()
    print(f"Étape 1/3: Analyse des fichiers JSON dans : {json_folder}")

    for filename in sorted(os.listdir(json_folder)):
        if filename.lower().endswith('.json'):
            file_path = os.path.join(json_folder, filename)
            try:
                with open(file_path, 'r', encoding='utf-8') as f: data = json.load(f)
                for model in data.get('models', []):
                    if model.get('imageUrl'):
                        valid_urls.add(model['imageUrl'])
            except Exception as e:
                print(f"  -> Attention: Erreur en lisant '{filename}': {e}")
    
    print(f"   -> Trouvé {len(valid_urls)} URLs d'images valides dans les fichiers JSON.")
    return valid_urls

def find_orphan_firebase_files(bucket, valid_urls, folder_prefix='models/'):
    """
    Liste les fichiers sur Firebase et identifie les orphelins.
    """
    print(f"\nÉtape 2/3: Analyse des fichiers dans Firebase Storage (dossier '{folder_prefix}')...")
    
    try:
        blobs = bucket.list_blobs(prefix=folder_prefix)
        orphan_files = []
        firebase_file_count = 0

        for blob in blobs:
            firebase_file_count += 1
            if blob.name.endswith('/'): continue

            if blob.public_url not in valid_urls:
                # On ne stocke que le nom du fichier, pas le chemin complet
                file_name_only = blob.name.replace(folder_prefix, '')
                orphan_files.append(file_name_only)
        
        print(f"   -> {firebase_file_count} fichiers trouvés dans Firebase.")
        print(f"   -> {len(orphan_files)} fichiers orphelins identifiés.")
        return orphan_files

    except Exception as e:
        print(f"❌ Erreur lors de la communication avec Firebase Storage : {e}")
        return None

def delete_orphan_files(bucket, orphan_files, folder_prefix='models/'):
    """
    Supprime une liste de fichiers de Firebase Storage après confirmation.
    """
    if not orphan_files:
        print("\n🎉 Aucun fichier orphelin à supprimer. Le nettoyage est terminé.")
        return

    print("\n" + "="*50)
    print("Étape 3/3: Suppression des fichiers orphelins")
    print("="*50)
    
    # --- ÉTAPE DE SÉCURITÉ : CONFIRMATION DE L'UTILISATEUR ---
    print("\nATTENTION : ACTION IRRÉVERSIBLE.")
    print(f"Vous êtes sur le point de supprimer DÉFINITIVEMENT {len(orphan_files)} fichiers de Firebase.")
    print("Voici un aperçu des premiers fichiers à supprimer :")
    for filename in orphan_files[:5]: # Affiche les 5 premiers
        print(f"  - {filename}")
    
    confirm = input("\nPour confirmer la suppression, veuillez taper 'OUI' en majuscules : ")

    if confirm != "OUI":
        print("\nOpération annulée par l'utilisateur. Aucun fichier n'a été supprimé.")
        return

    # --- PROCESSUS DE SUPPRESSION ---
    print("\nConfirmation reçue. Début de la suppression...")
    deleted_count = 0
    error_count = 0
    
    for filename in orphan_files:
        try:
            # Reconstituer le chemin complet du fichier dans le bucket
            blob_path = os.path.join(folder_prefix, filename).replace("\\", "/")
            blob = bucket.blob(blob_path)
            blob.delete()
            print(f"  -> ✅ Fichier '{filename}' supprimé.")
            deleted_count += 1
        except Exception as e:
            print(f"  -> ❌ Erreur lors de la suppression de '{filename}': {e}")
            error_count += 1
            
    print("\nOpération de nettoyage terminée.")
    print(f"Bilan : {deleted_count} fichiers supprimés, {error_count} erreurs.")


if __name__ == "__main__":
    # --- CHEMINS À CONFIGURER ---
    JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"
    FIREBASE_KEY = r"C:\Users\owenm\Documents\spot_my_car\serviceAccountKey.json"
    FIREBASE_BUCKET = 'car-spotter-app-779f2.firebasestorage.app'

    try:
        # Initialisation de Firebase
        if not firebase_admin._apps:
            cred = credentials.Certificate(FIREBASE_KEY)
            firebase_admin.initialize_app(cred, {'storageBucket': FIREBASE_BUCKET})
        
        bucket = storage.bucket()

        # Étape 1: Récupérer les URLs des JSON
        valid_image_urls = get_all_json_image_urls(JSON_MODELS_FOLDER)
        
        if valid_image_urls is not None:
            # Étape 2: Trouver les orphelins
            orphans_to_delete = find_orphan_firebase_files(bucket, valid_image_urls)
            
            if orphans_to_delete is not None:
                # Étape 3: Lancer le processus de suppression (avec confirmation)
                delete_orphan_files(bucket, orphans_to_delete)

    except FileNotFoundError:
        print(f"❌ ERREUR CRITIQUE: Le fichier de clé Firebase '{FIREBASE_KEY}' est introuvable.")
    except Exception as e:
        print(f"❌ ERREUR CRITIQUE: Une erreur inattendue est survenue: {e}")