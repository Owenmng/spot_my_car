# Fichier: main.py (Version Web Scraper)
import firebase_admin
from firebase_admin import auth
from flask import Request, jsonify

# Importations de ton code de scraping
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
import re

firebase_admin.initialize_app()

def clean_key(text):
    text = text.strip()
    if text.endswith(':'): text = text[:-1]
    text = re.sub(r'[ \[\]\(\)/\-]+', '_', text)
    text = re.sub(r'[^a-zA-Z0-9_\u00C0-\u017F]', '', text)
    text = text.lower()
    text = re.sub(r'__+', '_', text)
    return text

def lookup_plate(plate):
    print(f"Lancement du scraping pour la plaque: {plate}")
    plate_formatted = plate.replace("-", "").upper()

    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox") # Essentiel pour tourner dans Docker
    options.add_argument("--disable-dev-shm-usage") # Essentiel pour tourner dans Docker
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36")
    
    # Pas besoin d'installer le chromedriver, il est souvent géré par Selenium Manager
    driver = webdriver.Chrome(options=options)
    wait = WebDriverWait(driver, 30) # On augmente un peu le timeout, le scraping peut être lent

    try:
        driver.get("https://www.auto-doc.fr/")
        print("Page auto-doc.fr chargée.")
        cookie_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "button[data-cookies='allow_all_cookies']")))
        driver.execute_script("arguments[0].click();", cookie_button)
        print("Cookies acceptés.")
        input_field = wait.until(EC.presence_of_element_located((By.ID, "kba1")))
        driver.execute_script("arguments[0].value = arguments[1];", input_field, plate_formatted)
        print("Plaque saisie.")
        search_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, ".number-search__btn")))
        driver.execute_script("arguments[0].click();", search_button)
        print("Bouton de recherche cliqué.")
        wait.until(EC.invisibility_of_element_located((By.CLASS_NAME, "rc-loader")))
        info_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "span.btn[data-popup-show='data-popup-car-info']")))
        driver.execute_script("arguments[0].click();", info_button)
        print("Bouton d'informations cliqué.")
        popup = wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR, "div.popup--car-info")))
        wait.until(lambda d: popup.find_element(By.CLASS_NAME, "popup__title").text.strip() != "")
        
        data = {}
        title = popup.find_element(By.CLASS_NAME, "popup__title").text.strip()
        # On adapte la sortie pour qu'elle corresponde à ce que l'app Flutter attend
        # (make, model, etc.)
        parts = title.split(' ', 1)
        data['make'] = parts[0] if len(parts) > 0 else 'Inconnue'
        data['model'] = parts[1] if len(parts) > 1 else title
        data['registration'] = plate_formatted
        
        rows = popup.find_elements(By.CLASS_NAME, "popup__info-row")
        for row in rows:
            try:
                items = row.find_elements(By.CLASS_NAME, "popup__info-row-item")
                if len(items) >= 2:
                    key_clean = clean_key(items[0].text)
                    val = items[1].text.strip()
                    if key_clean: data[key_clean] = val
            except Exception: continue
        
        driver.quit()
        print("Scraping terminé avec succès.")
        return data
    except Exception as e:
        print(f"Erreur pendant le scraping: {e}")
        driver.quit()
        return None

# La fonction principale que Firebase va appeler
def get_vehicle_info_by_scraper(request: Request):
    print("--- Requête Scraper reçue ---")
    if request.method == 'OPTIONS':
        headers = {'Access-Control-Allow-Origin': '*','Access-Control-Allow-Methods': 'POST','Access-Control-Allow-Headers': 'Authorization, Content-Type','Access-Control-Max-Age': '3600'}
        return ('', 204, headers)
    headers = {'Access-Control-Allow-Origin': '*'}

    try:
        auth_header = request.headers.get('Authorization')
        id_token = auth_header.split('Bearer ')[1]
        auth.verify_id_token(id_token)
        print("Token OK.")
    except Exception: return (jsonify({"error": "Invalid token"}), 401, headers)

    request_json = request.get_json(silent=True)
    plate = request_json['plate']
    
    scraped_data = lookup_plate(plate)

    if scraped_data:
        return (jsonify(scraped_data), 200, headers)
    else:
        return (jsonify({"error": "Vehicle not found via scraping"}), 404, headers)