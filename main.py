import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime

# Connexion à MT5
if not mt5.initialize():
    print("Échec de l'initialisation de MT5, erreur :", mt5.last_error())
    quit()

# Paramètres
symbol = "GER40Cash"
timeframe = mt5.TIMEFRAME_H1  # Période H1 (ajustable : H4, D1, etc.)
start_date = datetime(2014, 1, 1)  # 1er janvier 2014 à 00:00
end_date = datetime(2024, 12, 31, 23, 59)  # 31 décembre 2024 à 23:59

# Récupérer les données
rates = mt5.copy_rates_range(symbol, timeframe, start_date, end_date)

if rates is None or len(rates) == 0:
    print("Aucune donnée récupérée. Vérifiez :")
    print("- Le symbole est correct (disponible dans MT5)")
    print("- La période contient des données (pas de jours fériés/manquants)")
    mt5.shutdown()
    quit()

# Convertir en DataFrame pandas
df = pd.DataFrame(rates)
df['time'] = pd.to_datetime(df['time'], unit='s')  # Conversion du timestamp

# Filtrer pour s'assurer que les dates sont dans l'intervalle
df = df[(df['time'] >= start_date) & (df['time'] <= end_date)]

# Export en CSV
filename = f"{symbol}_{start_date.date()}_to_{end_date.date()}.csv"
df.to_csv(filename, index=False)
print(f"Export réussi : {filename} ({len(df)} bougies)")

# Fermeture de MT5
mt5.shutdown()