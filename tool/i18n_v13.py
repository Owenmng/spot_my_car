"""Traductions : plan Pro (patron), carte, contact du jour, notifications, quêtes.
usage : python3 tool/i18n_v13.py"""
import json
import pathlib

T = [
    ("+{0} XP bonus encaissés !", "+{0} bonus XP collected!", "¡+{0} XP extra cobrados!", "+{0} Bonus-XP kassiert!", "+{0} XP bonus incassati!", "+{0} XP de bónus recebidos!"),
    ("Active la localisation", "Turn on location", "Activa la ubicación", "Standort aktivieren", "Attiva la posizione", "Ativa a localização"),
    ("Activer la localisation", "Turn on location", "Activar ubicación", "Standort aktivieren", "Attiva posizione", "Ativar localização"),
    ("Amis et duels", "Friends and duels", "Amigos y duelos", "Freunde und Duelle", "Amici e duelli", "Amigos e duelos"),
    ("Autorise la localisation", "Allow location", "Permite la ubicación", "Standort erlauben", "Consenti la posizione", "Permite a localização"),
    ("Avec Spot My Car+, chaque démarrage rapporte le double", "With Spot My Car+, every start pays double", "Con Spot My Car+, cada arranque da el doble",
     "Mit Spot My Car+ bringt jeder Start das Doppelte", "Con Spot My Car+, ogni avvio vale il doppio", "Com Spot My Car+, cada arranque vale o dobro"),
    ("CONTACT DU JOUR", "DAILY IGNITION", "ARRANQUE DEL DÍA", "TAGESSTART", "AVVIO DEL GIORNO", "ARRANQUE DO DIA"),
    ("Cette semaine, la cible est {0}. Prime : +{1} XP.", "This week's target is {0}. Bounty: +{1} XP.", "Esta semana el objetivo es {0}. Recompensa: +{1} XP.",
     "Diese Woche ist das Ziel {0}. Prämie: +{1} XP.", "Questa settimana l'obiettivo è {0}. Taglia: +{1} XP.", "Esta semana o alvo é {0}. Prémio: +{1} XP."),
    ("Contact du jour doublé", "Double daily ignition", "Arranque diario doble", "Doppelter Tagesstart", "Avvio del giorno doppio", "Arranque diário a dobrar"),
    ("Demandes d'amis et défis en duel", "Friend requests and duel challenges", "Solicitudes de amistad y retos", "Freundschaftsanfragen und Duelle", "Richieste di amicizia e sfide", "Pedidos de amizade e duelos"),
    ("Deux fois plus d'XP à chaque démarrage, sans pub", "Twice the XP at every start, no ads", "El doble de XP en cada arranque, sin anuncios",
     "Doppelte XP bei jedem Start, ohne Werbung", "Il doppio degli XP a ogni avvio, senza pubblicità", "O dobro de XP em cada arranque, sem anúncios"),
    ("DÉCOUVRIR", "EXPLORE", "DESCUBRIR", "ENTDECKEN", "SCOPRI", "DESCOBRIR"),
    ("Démarre le moteur : +{0} XP aujourd'hui.", "Start the engine: +{0} XP today.", "Arranca el motor: +{0} XP hoy.", "Starte den Motor: heute +{0} XP.", "Avvia il motore: +{0} XP oggi.", "Liga o motor: +{0} XP hoje."),
    ("Démarre ta série", "Start your streak", "Empieza tu racha", "Starte deine Serie", "Inizia la tua serie", "Começa a tua série"),
    ("EN ROUTE", "LET'S GO", "EN MARCHA", "LOS GEHT'S", "SI PARTE", "ARRANCAR"),
    ("Gratuit pour toi, patron", "Free for you, boss", "Gratis para ti, jefe", "Gratis für dich, Chef", "Gratis per te, capo", "Grátis para ti, chefe"),
    ("La localisation de ton téléphone est coupée. Active-la pour te voir sur la carte de chasse.", "Your phone's location is off. Turn it on to see yourself on the hunting map.",
     "La ubicación de tu teléfono está desactivada. Actívala para verte en el mapa.", "Der Standort deines Handys ist aus. Schalte ihn ein, um dich auf der Karte zu sehen.",
     "La posizione del telefono è disattivata. Attivala per vederti sulla mappa.", "A localização do telemóvel está desligada. Ativa-a para te veres no mapa."),
    ("MAX", "MAX", "MÁX", "MAX", "MAX", "MÁX"),
    ("Maintiens START pour démarrer", "Hold START to fire it up", "Mantén START para arrancar", "Halte START gedrückt", "Tieni premuto START", "Mantém START para arrancar"),
    ("Ouvre l'appli avant minuit pour garder tes {0} jours d'affilée.", "Open the app before midnight to keep your {0}-day streak.", "Abre la app antes de medianoche para mantener tus {0} días seguidos.",
     "Öffne die App vor Mitternacht, um deine {0}-Tage-Serie zu halten.", "Apri l'app prima di mezzanotte per tenere i tuoi {0} giorni di fila.", "Abre a app antes da meia-noite para manter os teus {0} dias seguidos."),
    ("Ouvrir les réglages", "Open settings", "Abrir ajustes", "Einstellungen öffnen", "Apri impostazioni", "Abrir definições"),
    ("Passe à Spot My Car+", "Go Spot My Car+", "Pásate a Spot My Car+", "Hol dir Spot My Car+", "Passa a Spot My Car+", "Muda para Spot My Car+"),
    ("Plein régime ! Une nouvelle série commence demain.", "Redline! A new streak starts tomorrow.", "¡A tope! Mañana empieza una nueva racha.",
     "Drehzahlbegrenzer! Morgen beginnt eine neue Serie.", "A tutto gas! Domani inizia una nuova serie.", "No máximo! Amanhã começa uma nova série."),
    ("QUÊTES DE LA SEMAINE", "WEEKLY QUESTS", "MISIONES SEMANALES", "WOCHENQUESTS", "MISSIONI SETTIMANALI", "MISSÕES DA SEMANA"),
    ("Quête terminée : +{0} XP", "Quest complete: +{0} XP", "Misión completada: +{0} XP", "Quest geschafft: +{0} XP", "Missione completata: +{0} XP", "Missão concluída: +{0} XP"),
    ("Reviens demain : +{0} XP au prochain démarrage", "Come back tomorrow: +{0} XP on the next start", "Vuelve mañana: +{0} XP en el próximo arranque",
     "Komm morgen wieder: +{0} XP beim nächsten Start", "Torna domani: +{0} XP al prossimo avvio", "Volta amanhã: +{0} XP no próximo arranque"),
    ("Sans autorisation, impossible de te placer sur la carte.", "Without permission we can't place you on the map.", "Sin permiso no podemos situarte en el mapa.",
     "Ohne Erlaubnis können wir dich nicht auf der Karte zeigen.", "Senza permesso non possiamo mostrarti sulla mappa.", "Sem permissão não te podemos mostrar no mapa."),
    ("Signal GPS trop faible. Réessaie à l'extérieur.", "GPS signal too weak. Try again outside.", "Señal GPS demasiado débil. Inténtalo fuera.",
     "GPS-Signal zu schwach. Versuch es draußen.", "Segnale GPS troppo debole. Riprova all'aperto.", "Sinal GPS fraco. Tenta lá fora."),
    ("Spot My Car+ est activé à vie sur ton compte. Profite de toutes les fonctionnalités Pro.", "Spot My Car+ is active for life on your account. Enjoy every Pro feature.",
     "Spot My Car+ está activado de por vida en tu cuenta. Disfruta de todas las funciones Pro.", "Spot My Car+ ist auf deinem Konto lebenslang aktiv. Viel Spaß mit allen Pro-Funktionen.",
     "Spot My Car+ è attivo a vita sul tuo account. Goditi tutte le funzioni Pro.", "O Spot My Car+ está ativo para sempre na tua conta. Aproveita todas as funções Pro."),
    ("Spotte dans {0} villes", "Spot in {0} cities", "Spotea en {0} ciudades", "Spotte in {0} Städten", "Spotta in {0} città", "Spota em {0} cidades"),
    ("Spotte une {0} avant minuit : +{1} XP", "Spot a {0} before midnight: +{1} XP", "Spotea un {0} antes de medianoche: +{1} XP", "Spotte einen {0} vor Mitternacht: +{1} XP",
     "Spotta una {0} prima di mezzanotte: +{1} XP", "Spota um {0} antes da meia-noite: +{1} XP"),
    ("Spotte {0} voitures", "Spot {0} cars", "Spotea {0} coches", "Spotte {0} Autos", "Spotta {0} auto", "Spota {0} carros"),
    ("Touche pour fermer", "Tap to close", "Toca para cerrar", "Zum Schließen tippen", "Tocca per chiudere", "Toca para fechar"),
    ("Tout est bouclé 🏁", "All done 🏁", "Todo listo 🏁", "Alles erledigt 🏁", "Tutto fatto 🏁", "Tudo feito 🏁"),
    ("Tu as refusé l'accès à ta position. Autorise-le dans les réglages de l'appli pour te voir sur la carte.", "You denied location access. Allow it in the app settings to see yourself on the map.",
     "Denegaste el acceso a tu ubicación. Permítelo en los ajustes de la app para verte en el mapa.", "Du hast den Standortzugriff verweigert. Erlaube ihn in den App-Einstellungen.",
     "Hai negato l'accesso alla posizione. Consentilo nelle impostazioni dell'app.", "Recusaste o acesso à localização. Permite-o nas definições da app."),
    ("Une voiture rare ou mieux", "A rare car or better", "Un coche raro o mejor", "Ein seltenes Auto oder besser", "Un'auto rara o meglio", "Um carro raro ou melhor"),
    ("XP doublée, thèmes exclusifs, zéro pub", "Double XP, exclusive themes, no ads", "XP doble, temas exclusivos, sin anuncios", "Doppelte XP, exklusive Designs, keine Werbung",
     "XP doppi, temi esclusivi, zero pubblicità", "XP a dobrar, temas exclusivos, zero anúncios"),
    ("{0} jours d'affilée", "{0} days in a row", "{0} días seguidos", "{0} Tage in Folge", "{0} giorni di fila", "{0} dias seguidos"),
    ("{0} marques différentes", "{0} different brands", "{0} marcas distintas", "{0} verschiedene Marken", "{0} marche diverse", "{0} marcas diferentes"),
    ("{0} · +{1} XP avant minuit", "{0} · +{1} XP before midnight", "{0} · +{1} XP antes de medianoche", "{0} · +{1} XP vor Mitternacht", "{0} · +{1} XP prima di mezzanotte", "{0} · +{1} XP antes da meia-noite"),
    ("{0}/{1} · reset dans {2} j", "{0}/{1} · resets in {2} d", "{0}/{1} · se reinicia en {2} d", "{0}/{1} · Reset in {2} T", "{0}/{1} · reset tra {2} g", "{0}/{1} · reinicia em {2} d"),
    ("×2 XP avec une courte vidéo (+{0})", "×2 XP with a short video (+{0})", "×2 XP con un vídeo corto (+{0})", "×2 XP mit kurzem Video (+{0})", "×2 XP con un breve video (+{0})", "×2 XP com um vídeo curto (+{0})"),
    ("⏳ Plus que 3 h 30 pour le défi du jour", "⏳ 3.5 hours left for today's challenge", "⏳ Quedan 3 h 30 para el reto del día", "⏳ Noch 3,5 Std. für die Tagesaufgabe",
     "⏳ Restano 3 h 30 per la sfida del giorno", "⏳ Faltam 3 h 30 para o desafio do dia"),
    ("🎯 Avis de recherche : dernières heures", "🎯 Wanted: final hours", "🎯 Se busca: últimas horas", "🎯 Gesucht: letzte Stunden", "🎯 Ricercata: ultime ore", "🎯 Procura-se: últimas horas"),
    ("🎯 Nouvel avis de recherche", "🎯 New wanted target", "🎯 Nuevo «Se busca»", "🎯 Neues Gesucht-Ziel", "🎯 Nuova ricercata", "🎯 Novo procura-se"),
    ("🔑 Ta série de démarrages est en jeu", "🔑 Your ignition streak is at stake", "🔑 Tu racha de arranques está en juego", "🔑 Deine Start-Serie steht auf dem Spiel",
     "🔑 La tua serie di avvii è in gioco", "🔑 A tua série de arranques está em jogo"),
    ("🔑 Ton moteur t'attend", "🔑 Your engine is waiting", "🔑 Tu motor te espera", "🔑 Dein Motor wartet", "🔑 Il tuo motore ti aspetta", "🔑 O teu motor está à espera"),
]

root = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'i18n'
for col, lang in enumerate(['fr', 'en', 'es', 'de', 'it', 'pt']):
    p = root / f'{lang}.json'
    data = json.loads(p.read_text())
    n = 0
    for row in T:
        if row[0] not in data:
            data[row[0]] = row[col]
            n += 1
    p.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + '\n')
    print(lang, '+', n)
