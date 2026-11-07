# Utilise une image de base Python 3.11 fournie par Google
FROM python:3.11-slim

# Définit le répertoire de travail dans le conteneur
WORKDIR /app

# Met à jour les paquets et installe les dépendances nécessaires pour Chrome
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    unzip \
    # Dépendances pour faire tourner Chrome en mode headless
    libglib2.0-0 \
    libnss3 \
    libgconf-2-4 \
    libfontconfig1 \
    --no-install-recommends

# Télécharge et installe Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable

# Copie le fichier des dépendances Python
COPY requirements.txt .

# Installe les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie le reste du code de l'application
COPY . .

# Commande pour lancer le serveur de la fonction (fournie par Google)
CMD exec functions-framework --target=get_vehicle_info_by_scraper --port=8080