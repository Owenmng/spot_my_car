from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
import re

def clean_key(text):
    text = text.strip()
    if text.endswith(':'):
        text = text[:-1]
    text = re.sub(r'[ \[\]\(\)/\-]+', '_', text)
    text = re.sub(r'[^a-zA-Z0-9_\u00C0-\u017F]', '', text)
    text = text.lower()
    text = re.sub(r'__+', '_', text)
    return text

def lookup_plate(plate):
    plate_formatted = plate.replace("-", "").upper()

    options = webdriver.ChromeOptions()
    options.add_argument("--incognito")
    options.add_argument("--headless")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36")
    options.add_argument("--disable-blink-features=AutomationControlled")

    driver = webdriver.Chrome(options=options)
    wait = WebDriverWait(driver, 20)  # 20s timeout max

    try:
        driver.get("https://www.auto-doc.fr/")

        # Accepter les cookies (bouton)
        cookie_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "button[data-cookies='allow_all_cookies']")))
        driver.execute_script("arguments[0].click();", cookie_button)

        # Saisie plaque
        input_field = wait.until(EC.presence_of_element_located((By.ID, "kba1")))
        driver.execute_script("arguments[0].value = arguments[1];", input_field, plate_formatted)

        # Clic sur bouton recherche
        search_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, ".number-search__btn")))
        driver.execute_script("arguments[0].click();", search_button)

        # Attendre que le loader disparaisse (indique fin du chargement)
        wait.until(EC.invisibility_of_element_located((By.CLASS_NAME, "rc-loader")))

        # Attendre que le bouton "Informations du véhicule" soit cliquable
        info_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, "span.btn[data-popup-show='data-popup-car-info']")))
        driver.execute_script("arguments[0].click();", info_button)

        # Attendre que la popup soit visible
        popup = wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR, "div.popup--car-info")))

        # Attendre que le titre soit chargé (présence du texte)
        wait.until(lambda d: popup.find_element(By.CLASS_NAME, "popup__title").text.strip() != "")

        data = {}
        try:
            title = popup.find_element(By.CLASS_NAME, "popup__title").text.strip()
            data['modele'] = title
        except Exception:
            pass

        rows = popup.find_elements(By.CLASS_NAME, "popup__info-row")
        for row in rows:
            try:
                items = row.find_elements(By.CLASS_NAME, "popup__info-row-item")
                if len(items) >= 2:
                    key_clean = clean_key(items[0].text)
                    val = items[1].text.strip()
                    if key_clean:
                        data[key_clean] = val
            except Exception:
                continue

    except TimeoutException as e:
        print(f"Erreur : Timeout ou élément non trouvé - {e}")
        driver.quit()
        return None
    except Exception as e:
        print(f"Erreur inconnue : {e}")
        driver.quit()
        return None

    driver.quit()
    return data

def print_vehicle_info(data):
    print("\n--- Informations Véhicule Récupérées ---")
    for k, v in data.items():
        print(f"{k} : {v}")
    print("--- Fin ---\n")

if __name__ == "__main__":
    plaque_test = input('plaque test : ')
    print(f"Lancement de la recherche pour la plaque : {plaque_test}")
    infos = lookup_plate(plaque_test)
    
    if infos:
        print_vehicle_info(infos)
    else:
        print("Échec de la récupération des informations.")
