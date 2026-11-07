# Fichier: clean_world_cities.py (Version avec correction de l'apostrophe)

import json

def format_city_name(name):
    """
    Formate un nom de ville en enlevant les apostrophes en début/fin
    et en mettant la première lettre de chaque mot en majuscule.
    """
    if not name:
        return ""
    # ==========================================================
    # === LA CORRECTION EST ICI ================================
    # ==========================================================
    # On ajoute .strip("'") pour nettoyer les apostrophes indésirables
    return name.strip().strip("'").title()


input_filename = 'csvjson.json'
output_filename = 'world_cities_cleaned.json'

print(f"--- Lancement du script de nettoyage pour les villes du monde ---")
print(f"Lecture du fichier d'entrée: {input_filename}")

try:
    with open(input_filename, 'r', encoding='utf-8') as f_in:
        list_of_cities = json.load(f_in)

    print(f"Nombre de villes à traiter: {len(list_of_cities)}")

    cleaned_cities = []
    unique_cities = set() 

    for city_data in list_of_cities:
        city_name = city_data.get('city_ascii')
        country_name = city_data.get('country')
        latitude = city_data.get('lat')
        longitude = city_data.get('lng')

        if city_name and country_name:
            formatted_name = format_city_name(city_name) # Appel à la fonction corrigée
            unique_identifier = f"{formatted_name}|{country_name}"
            
            if unique_identifier not in unique_cities:
                cleaned_cities.append({
                    'nom': f"{formatted_name} - {country_name}", 
                    'latitude': float(latitude) if latitude else 0.0,
                    'longitude': float(longitude) if longitude else 0.0,
                })
                unique_cities.add(unique_identifier)

    cleaned_cities.sort(key=lambda x: x['nom'])

    print(f"Nombre de villes uniques après nettoyage: {len(cleaned_cities)}")
    print(f"Écriture dans le fichier de sortie: {output_filename}")

    with open(output_filename, 'w', encoding='utf-8') as f_out:
        json.dump(cleaned_cities, f_out, ensure_ascii=False, indent=2)

    print(f"--- Script terminé avec succès ! Le fichier '{output_filename}' a été créé. ---")

except FileNotFoundError:
    print(f"ERREUR: Le fichier '{input_filename}' n'a pas été trouvé.")
except Exception as e:
    print(f"Une erreur inattendue est survenue: {e}")