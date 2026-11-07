import os
import hashlib
import shutil
from collections import defaultdict
from tqdm import tqdm
import json

# --- NOUVEAUX IMPORTS POUR FIREBASE ---
import firebase_admin
from firebase_admin import credentials, storage

# ==============================================================================
# --- CONFIGURATION - TOUT EST À RÉGLER ICI ---
# ==============================================================================

# --- SÉCURITÉ ---
# True = Mode SIMULATION. Affiche ce qui serait supprimé SANS RIEN TOUCHER.
# False = Mode RÉEL. Lance les suppressions pour de vrai.
DRY_RUN = True 

# --- CHEMINS LOCAUX ---
# Dossier contenant toutes les images à analyser
# Dossier où les doublons seront copiés (pour vérification manuelle si besoin)
DESTINATION_FOLDER = r"C:\Users\owenm\Downloads\doublons_a_supprimer"
# Dossier contenant tes fichiers JSON de modèles (ex: ferrari.json, porsche.json...)
JSON_MODELS_FOLDER = r"C:\Users\owenm\Documents\spot_my_car\assets\data\models_by_brand"

# --- CONFIGURATION FIREBASE ---
# Chemin complet vers ta clé de service que tu viens de télécharger
SERVICE_ACCOUNT_KEY_PATH = r"C:\Users\owenm\Documents\spot_my_car\car-spotter-app-779f2-firebase-adminsdk-fbsvc-4a7d0bed3f.json"
# Nom de ton "Bucket" Firebase Storage. Trouve-le dans la console Firebase -> Storage.
# Ça ressemble à "ton-projet-id.appspot.com"
BUCKET_NAME = "car-spotter-app-779f2.firebasestorage.app"
# Le dossier dans Firebase Storage où se trouvent les images des modèles
FIREBASE_MODELS_FOLDER = "models"

# --- CHEMINS À CONFIGURER ---
# Le dossier contenant toutes vos images téléchargées
SOURCE_FOLDER = r"C:\Users\owenm\Downloads\modeles_image"
# ==============================================================================
# --- FONCTIONS UTILITAIRES (inchangées) ---
# ==============================================================================

def calculate_hash(filepath, block_size=65536):
    """Calcule le hash SHA-256 d'un fichier."""
    sha256 = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            for block in iter(lambda: f.read(block_size), b''):
                sha256.update(block)
        return sha256.hexdigest()
    except IOError as e:
        print(f"Attention: Impossible de lire le fichier {filepath}: {e}")
        return None

def find_duplicates(folder_path):
    """Trouve les fichiers en double et retourne un dictionnaire de listes de doublons."""
    if not os.path.isdir(folder_path):
        print(f"Erreur: Le dossier '{folder_path}' n'existe pas.")
        return {}
    hashes = defaultdict(list)
    image_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.bmp')
    files_to_scan = [f for f in os.listdir(folder_path) if f.lower().endswith(image_extensions)]
    print(f"Analyse de {len(files_to_scan)} images dans '{folder_path}'...")
    for filename in tqdm(files_to_scan, desc="Analyse des images"):
        filepath = os.path.join(folder_path, filename)
        file_hash = calculate_hash(filepath)
        if file_hash:
            hashes[file_hash].append(filepath)
    return {hash_val: paths for hash_val, paths in hashes.items() if len(paths) > 1}

# ==============================================================================
# --- NOUVELLES FONCTIONS DE SUPPRESSION ---
# ==============================================================================

def initialize_firebase():
    """Initialise la connexion à Firebase Admin."""
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
        firebase_admin.initialize_app(cred, {'storageBucket': BUCKET_NAME})
        print("✅ Connexion à Firebase réussie.")
        return storage.bucket()
    except Exception as e:
        print(f"🚨 ERREUR FATALE: Impossible de se connecter à Firebase. Vérifie ton chemin de clé et le nom du bucket.")
        print(f"   Détails: {e}")
        return None

def delete_from_json(model_ids_to_delete_by_brand, dry_run=True):
    """Supprime les entrées de modèles des fichiers JSON."""
    print("\n--- Suppression des entrées JSON ---")
    if not model_ids_to_delete_by_brand:
        print("Aucune entrée JSON à supprimer.")
        return

    for brand_id, model_ids in model_ids_to_delete_by_brand.items():
        json_path = os.path.join(JSON_MODELS_FOLDER, f"{brand_id}.json")
        if not os.path.exists(json_path):
            print(f"  -> ⚠️ Fichier JSON non trouvé pour la marque '{brand_id}', ignoré : {json_path}")
            continue

        print(f"  -> Traitement du fichier : {os.path.basename(json_path)}")
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            initial_count = len(data.get('models', []))
            # On filtre la liste pour ne garder que les modèles NON supprimés
            models_kept = [model for model in data.get('models', []) if model.get('id') not in model_ids]
            
            if len(models_kept) < initial_count:
                print(f"     - {initial_count - len(models_kept)} modèle(s) à supprimer: {', '.join(model_ids)}")
                if not dry_run:
                    data['models'] = models_kept
                    with open(json_path, 'w', encoding='utf-8') as f:
                        json.dump(data, f, indent=2, ensure_ascii=False)
                    print("     - ✅ Fichier JSON mis à jour.")
                else:
                    print("     -  DRY RUN: Fichier JSON non modifié.")
            else:
                print(f"     - Aucun des modèles spécifiés ({', '.join(model_ids)}) n'a été trouvé dans le JSON.")

        except Exception as e:
            print(f"     - 🚨 ERREUR lors du traitement de {os.path.basename(json_path)}: {e}")


def delete_from_firebase(files_to_delete, bucket, dry_run=True):
    """Supprime les fichiers de Firebase Storage."""
    print("\n--- Suppression des images sur Firebase Storage ---")
    if not files_to_delete:
        print("Aucune image à supprimer sur Firebase.")
        return
        
    for filepath in tqdm(files_to_delete, desc="Vérification/Suppression Firebase"):
        filename = os.path.basename(filepath)
        remote_path = f"{FIREBASE_MODELS_FOLDER}/{filename}"
        blob = bucket.blob(remote_path)

        if blob.exists():
            print(f"  -> Trouvé sur Firebase: {remote_path}")
            if not dry_run:
                try:
                    blob.delete()
                    print(f"     - ✅ Supprimé de Firebase.")
                except Exception as e:
                    print(f"     - 🚨 ERREUR de suppression Firebase: {e}")
            else:
                print("     - DRY RUN: Fichier non supprimé.")
        else:
            print(f"  -> ⚠️ Non trouvé sur Firebase, ignoré : {remote_path}")


def delete_local_files(files_to_delete, dry_run=True):
    """Supprime les fichiers image en double du dossier local."""
    print("\n--- Suppression des images locales en double ---")
    if not files_to_delete:
        print("Aucun fichier local à supprimer.")
        return
        
    for filepath in files_to_delete:
        print(f"  -> Fichier local à supprimer: {os.path.basename(filepath)}")
        if not dry_run:
            try:
                os.remove(filepath)
                print("     - ✅ Fichier local supprimé.")
            except OSError as e:
                print(f"     - 🚨 ERREUR de suppression locale: {e}")
        else:
            print("     - DRY RUN: Fichier local non supprimé.")


if __name__ == "__main__":
    print("="*60)
    print("Lancement de l'outil de suppression de doublons")
    if DRY_RUN:
        print("MODE SIMULATION (DRY RUN) ACTIVÉ - AUCUN FICHIER NE SERA MODIFIÉ OU SUPPRIMÉ")
    else:
        print("/!\\ MODE RÉEL ACTIVÉ - LES FICHIERS ET DONNÉES SERONT SUPPRIMÉS DÉFINITIVEMENT /!\\")
    print("="*60)

    # 1. Trouver tous les groupes de doublons
    duplicate_groups = find_duplicates(SOURCE_FOLDER)

    if not duplicate_groups:
        print("\n🎉 Aucune image en double n'a été trouvée !")
        exit()

    print(f"\n🚨 RAPPORT : {len(duplicate_groups)} groupe(s) d'images en double trouvé(s) 🚨\n")

    # 2. Préparer les listes de suppression
    all_files_to_delete = []
    models_to_delete_by_brand = defaultdict(list)

    for i, (hash_val, paths) in enumerate(duplicate_groups.items()):
        # On garde le premier fichier de la liste comme original
        original_file = os.path.basename(paths[0])
        duplicate_files = [os.path.basename(p) for p in paths[1:]]
        
        print(f"--- Groupe de doublons n°{i+1} ---")
        print(f"  -> Original conservé : {original_file}")
        print(f"  -> Doublons à traiter : {', '.join(duplicate_files)}")
        print("-" * 50)
        
        all_files_to_delete.extend(paths[1:])
        
        for dup_path in paths[1:]:
            filename = os.path.basename(dup_path)
            model_id = os.path.splitext(filename)[0]
            # On suppose que le nom de fichier est 'marque_modele.jpg'
            brand_id = model_id.split('_')[0]
            models_to_delete_by_brand[brand_id].append(model_id)

    # 3. Copier les doublons à supprimer dans un dossier de sécurité
    print(f"\nCopie de {len(all_files_to_delete)} doublons vers '{DESTINATION_FOLDER}' pour sécurité...")
    os.makedirs(DESTINATION_FOLDER, exist_ok=True)
    for source_path in tqdm(all_files_to_delete, desc="Copie de sécurité"):
        shutil.copy2(source_path, DESTINATION_FOLDER)
    print("✅ Copie de sécurité terminée.")

    # 4. Lancer les opérations de suppression
    if DRY_RUN:
        print("\n--- DÉBUT DE LA SIMULATION DE SUPPRESSION ---")
    else:
        input("\nAppuyez sur ENTRÉE pour commencer la suppression définitive...")
        print("\n--- DÉBUT DE LA SUPPRESSION DÉFINITIVE ---")

    # Initialisation de Firebase
    firebase_bucket = initialize_firebase()
    
    if firebase_bucket:
        # L'ordre est important : d'abord les dépendances (JSON, Firebase), puis le fichier local
        delete_from_json(models_to_delete_by_brand, dry_run=DRY_RUN)
        delete_from_firebase(all_files_to_delete, firebase_bucket, dry_run=DRY_RUN)
        delete_local_files(all_files_to_delete, dry_run=DRY_RUN)

    print("\nOpération terminée.")