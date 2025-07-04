//+------------------------------------------------------------------+
//|                                                  ApoloSignal.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Inclusion nécessaire pour utiliser les fonctions des indicateurs
#include <Indicators\Indicators.mqh> 

//+------------------------------------------------------------------+
//| Vérifie les signaux Heiken Ashi et gère les positions            |
//+------------------------------------------------------------------+
void CheckHeikenAshiSignals()
{
  // Récupération des données Heiken Ashi
  if(CopyBuffer(ha_handle, 0, 0, 3, ha_open_buffer) < 3 ||
      CopyBuffer(ha_handle, 1, 0, 3, ha_high_buffer) < 3 ||
      CopyBuffer(ha_handle, 2, 0, 3, ha_low_buffer) < 3 ||
      CopyBuffer(ha_handle, 3, 0, 3, ha_close_buffer) < 3) 
  {
      Print("⚠️ Échec de la copie des valeurs Heiken Ashi !");
      return;
  }

  if(ArraySize(ha_open_buffer) < 3) 
  {
      Print("⚠️ Erreur : Pas assez de données dans les buffers !");
      return;
  }

  // Vérification de l'écart
  double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
  if(spread > MaxSpread)
  {
      Print("⚠️ Écart trop élevé : ", spread, " points. Position non ouverte.");
      return;
  }

  // Vérification des positions existantes
  bool hasLongPosition = false;
  bool hasShortPosition = false;

  // Signaux par Indicateurs
  string signal = GetSignal();
  string rsiSignal = GetRSISignal();

  // Asiatic Session Check
  bool isAsianSession = IsAsianSession();
  
  if(PositionSelect(_Symbol))
  {
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      hasLongPosition = true;
    else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      hasShortPosition = true;
  }

  // Signal d'achat - Deux bougies haussières consécutives
  if( ha_close_buffer[0] > ha_open_buffer[0] && 
      ha_close_buffer[1] > ha_open_buffer[1] && 
      ha_close_buffer[2] > ha_open_buffer[2] && 
      signal == "BUY" && rsiSignal == "NEUTRAL"
      && isAsianSession == false)
  {
      Print("🔹 Signal ACHAT - Deux bougies bleues consécutives");
      
      // Si nous avons déjà une position courte, on la ferme
      if(hasShortPosition)
      {
        CloseAllPositions();
        Print("Position courte fermée pour ouvrir un achat");
      }
      
      // Si pas de position longue ouverte, on ouvre une position
      if(!hasLongPosition)
      {
        OpenBuyPosition();
      }
  }
  // Signal de vente - Deux bougies baissières consécutives
  else if(ha_close_buffer[0] < ha_open_buffer[0] && 
    ha_close_buffer[1] < ha_open_buffer[1] && 
    ha_close_buffer[2] < ha_open_buffer[2] &&
    signal == "SELL" && rsiSignal == "NEUTRAL" && isAsianSession == false)
  {
    Print("🔻 Signal VENTE - Deux bougies rouges consécutives");
    
    // Si nous avons déjà une position longue, on la ferme
    if(hasLongPosition)
    {
      CloseAllPositions();
      Print("Position longue fermée pour ouvrir une vente");
    }
    
    // Si pas de position courte ouverte, on ouvre une position
    if(!hasShortPosition)
    {
      OpenSellPosition();
    }
  }
}