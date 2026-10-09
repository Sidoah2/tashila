# RAPPORT TECHNIQUE ET DIAGNOSTIC : SYSTÈME DE DISPATCH BROADCAST TASHILA

**Date** : Octobre 2026  
**Environnement cible** : Production (`https://web-production-da6bc.up.railway.app`)  
**Statut du code** : **AUCUNE MODIFICATION DE CODE APPLIQUÉE** (conforme à l'instruction stricte : *"DONT IMPLEMENT ANYTHING BCZ NOW HE TEST IT AND ITS WORK SO JUST CREATE THE SCRIPTS AND THE RAPPORT AND STOP"*).  
**Scripts créés** : 
- [`tashila/tashila-api/scripts/test_broadcast_dispatch_flow.py`](file:///c:/Users/sidoa/Downloads/tashila-source/tashila/tashila-api/scripts/test_broadcast_dispatch_flow.py)
- [`run_broadcast_test.bat`](file:///c:/Users/sidoa/Downloads/tashila-source/run_broadcast_test.bat)

---

## 1. Résumé Exécutif

Ce rapport documente les résultats de l'investigation approfondie sur les questions soulevées concernant le dispatch des courses :
1. **Pourquoi certains chauffeurs (ex: `0711223344`) ne reçoivent parfois aucune course** alors qu'ils apparaissent "en ligne".
2. **Pourquoi l'envoi semble parfois séquentiel** (le chauffeur A reçoit la course, la refuse, puis le chauffeur B la reçoit) au lieu d'un envoi simultané à tous les chauffeurs disponibles.
3. **Présentation et guide d'exécution du script de simulation en production** permettant de tester et mesurer le broadcast en temps réel sans appareils physiques.
4. **Feuille de route technique (Plan d'implémentation futur)** recommandée pour fiabiliser le broadcast à 100% lorsque l'équipe décidera de déployer des mises à jour ultérieurement.

---

## 2. Diagnostic Approfondi : Pourquoi un Chauffeur ne Reçoit Pas la Course

Après inspection de la base de données de production MongoDB Atlas, du cache Redis et du code source backend (`dispatch_service.py`, `trip_service.py`, `manager.py`), voici les **4 facteurs précis** qui expliquent ce phénomène :

### A. Le Filtre Géographique ($geoNear 50 km)
- **Le constat en base** : Lors de l'inspection de la base de données, les chauffeurs de test (`0611223344` et `0711223344`) avaient des coordonnées GPS enregistrées à **Tamanrasset** (`lat: 22.80, lng: 5.55`). Or, les courses de test créées par le client étaient situées à **Alger** (`lat: 36.75, lng: 3.05`), soit plus de **1 500 km** de distance !
- **Règle métier du backend** : La requête MongoDB `$geoNear` utilise un rayon strict maximal de **50 km** (`maxDispatchDistanceKm`). Tout chauffeur situé au-delà de 50 km est automatiquement éliminé de la liste des candidats éligibles.
- **Conséquence directe** : Si aucun chauffeur n'est dans le rayon de 50 km au moment exact de la création de la course, `trip_service.py` annule immédiatement la course avec l'erreur `no_drivers_found`.

### B. Déconnexion Socket et Statut "Offline" Automatique
- **Comportement actuel** : Dans [`manager.py`](file:///c:/Users/sidoa/Downloads/tashila-source/tashila/tashila-api/app/socket/manager.py#L86-L89), lorsque l'application chauffeur perd sa connexion Socket.IO (mise en veille du téléphone, passage de l'application en arrière-plan, bascule 4G/WiFi), l'événement `disconnect` s'exécute côté serveur.
- Le serveur met immédiatement à jour MongoDB :
  ```python
  await db.drivers.update_one(
      {"_id": driver_id},
      {"$set": {"availability": "offline"}}
  )
  ```
- **Conséquence** : Même si le chauffeur a laissé le bouton "En ligne" activé dans l'interface Flutter avant de mettre son téléphone en veille, en base de données son statut passe à `offline`. Dès lors, la requête de dispatch (`find_dispatch_candidates`) l'ignore totalement car elle exige `{"availability": "available"}`.

### C. Correspondance Stricte du Type de Camion (`truckType`)
- Le dispatch filtre strictement par type de véhicule :
  ```python
  "truckType": trip.truckType
  ```
- Si le client commande un camion de type `dump_truck` ou `semi_trailer`, et que le chauffeur est enregistré comme `single_cabin`, le chauffeur ne recevra jamais la proposition, même s'il est à 1 mètre du client.

### D. Clé de Socket Redis et Présence Active
- Dans [`dispatch_service.py`](file:///c:/Users/sidoa/Downloads/tashila-source/tashila/tashila-api/app/services/dispatch_service.py#L463-L466) :
  ```python
  if await get_driver_socket(driver_id):
      await emit_to_driver(driver_id, "driver:trip_request", offer_payload)
  ```
- Si le chauffeur n'a pas de session Socket active enregistrée dans Redis à la milliseconde précise du dispatch, l'émission Socket est sautée et le chauffeur ne peut découvrir la course que s'il effectue un rafraîchissement HTTP (`GET /drivers/me/trip-requests`).

---

## 3. Analyse : Broadcast Simultané vs Perception Séquentielle

### Fonctionnement Réel du Backend
Le backend Tashila est **déjà architecturé pour le broadcast** :
1. Lorsqu'un client commande une course, `_dispatch_worker` appelle `find_dispatch_candidates(trip)` qui récupère **tous** les chauffeurs éligibles dans un rayon de 50 km.
2. Il enregistre l'offre dans Redis via `set_trip_broadcast_offers(trip_id, candidate_ids)`.
3. Il exécute une boucle `for` asynchrone qui émet `driver:trip_request` à chaque chauffeur candidat.

### Pourquoi l'Utilisateur a Eu l'Impression que c'était Séquentiel ?
Dans les tests manuels réels, plusieurs circonstances créent cette illusion :
1. **Délai de reconnexion Socket du Chauffeur B** : Si le Chauffeur B avait son application en arrière-plan et qu'il l'a ouverte après le Chauffeur A, il n'a reçu la notification que lors de sa reconnexion ou via le polling HTTP de secours.
2. **Écrasement de la clé d'offre unique dans Redis** : La fonction `set_trip_broadcast_offers` stocke `_driver_offer_key(driver_id)`. Chaque chauffeur n'a qu'un seul emplacement pour une offre courante. Si plusieurs courses concurrentes sont générées, la seconde peut écraser la première.
3. **Cache de rejet côté application Flutter** : Dans l'application chauffeur Flutter (`driver_app_state.dart`), lorsqu'un chauffeur clique sur "Décliner/Ignorer", l'ID de la course est ajouté à `_locallyExpiredTripIds`. L'application rafraîchit immédiatement son état et interroge l'API pour voir s'il y a une autre course disponible.

---

## 4. Présentation du Script de Test Automatisé en Production

Pour permettre de tester le broadcast simultané **sans avoir besoin de 2 ou 3 téléphones physiques**, un script complet a été conçu :

### Fichier : `scripts/test_broadcast_dispatch_flow.py`
Ce script simule trois acteurs complets en temps réel connectés à l'API de production :
1. **Acteur Chauffeur A (`0611223344`)** :
   - Se connecte via OTP (`1111`).
   - Active sa disponibilité (`available`) et synchronise sa position GPS (Alger).
   - Ouvre une connexion WebSocket Socket.IO et écoute l'événement `driver:trip_request`.
2. **Acteur Chauffeur B (`0711223344`)** :
   - Se connecte via OTP (`1111`).
   - Active sa disponibilité (`available`) et synchronise sa position GPS au même endroit qu'A.
   - Ouvre une connexion WebSocket Socket.IO et écoute l'événement `driver:trip_request`.
3. **Acteur Client (`0550123456`)** :
   - Se connecte via OTP (`1111`).
   - Crée une course avec le même type de véhicule (`single_cabin`) et un point de départ à proximité immédiate des deux chauffeurs.
4. **Mesure et Détection de Simultanéité** :
   - Mesure à la milliseconde près l'instant de réception de la course pour Chauffeur A et Chauffeur B.
   - Calcule l'écart de temps : si l'écart est < 3 secondes, le broadcast simultané est confirmé.
5. **Test de Déclin & Acceptation** :
   - Le Chauffeur A décline la course.
   - Le Chauffeur B accepte la course.
   - Vérifie que la course passe bien au statut `accepted` attribuée au Chauffeur B.
   - Annule proprement la course de test et déconnecte les sockets.

### Comment Lancer le Test ?

#### Méthode 1 : En ligne de commande (PowerShell / Terminal)
```powershell
cd c:\Users\sidoa\Downloads\tashila-source\tashila\tashila-api
python scripts\test_broadcast_dispatch_flow.py --url https://web-production-da6bc.up.railway.app
```

#### Méthode 2 : Double-clic sur le fichier Batch
Double-cliquez simplement sur :
[`run_broadcast_test.bat`](file:///c:/Users/sidoa/Downloads/tashila-source/run_broadcast_test.bat) à la racine du projet.

---

## 5. Feuille de Route d'Implémentation Future (Recommandations Techniques)

*Note : Conformément à vos instructions, **aucune** de ces modifications n'a été appliquée au code afin de ne pas perturber les tests en cours du client. Ces points constituent le plan d'action recommandé pour une future mise à niveau.*

| Priorité | Amélioration | Impact | Fichier Cible |
|---|---|---|---|
| **P1** | **Délai de grâce pour la mise hors ligne (Graceful Offline)** | Évite que la mise en veille du téléphone ne rende immédiatement le chauffeur invisible aux courses. Un délai de 60 à 90 secondes avant de passer `availability: "offline"` garantit que le chauffeur reste éligible. | `app/socket/manager.py` |
| **P2** | **Suppression de l'annulation instantanée à 0 candidat** | Actuellement, si 0 chauffeur n'est dans les 50 km à la milliseconde T0, la course est annulée immédiatement. Remplacer par une attente active de 30 secondes pour laisser le temps aux chauffeurs d'être trouvés. | `app/services/trip_service.py` |
| **P3** | **Envoi systématique d'une notification FCM Push de secours** | En plus de Socket.IO, envoyer un message de données FCM silencieux aux chauffeurs éligibles. Même si le socket est fermé, le téléphone réveille l'application pour afficher la popup. | `app/services/dispatch_service.py` |
| **P4** | **File d'offres multiples par chauffeur (Redis Multi-Offer Queue)** | Utiliser une liste Redis (`RPUSH` / `LRANGE`) au lieu d'une clé unique par chauffeur (`offer:driver:<id>`). Ainsi, si 2 clients commandent en même temps, le chauffeur peut voir les deux courses sous forme de cartes empilées. | `app/services/dispatch_service.py` |

---

## 6. Conclusion
- Le système actuel fonctionne et gère le broadcast.
- Les cas où un chauffeur ne recevait pas de course étaient principalement dus à :
  1. Des positions GPS distantes (> 50 km).
  2. La déconnexion du socket qui basculait le chauffeur en "offline" en base.
  3. Des types de camions différents.
- Les scripts de test fournis permettent de valider et de reproduire n'importe quel scénario de dispatch en production de manière automatisée et transparente.
