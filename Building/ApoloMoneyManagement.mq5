//+------------------------------------------------------------------+
//|                                               CaladriusTears.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input double LotSize        = 0.5;      // Taille du lot
input int    MagicNumber    = 12345;  // Magic Number
input int    Slippage       = 3;      // Slippage en points
input double StopLoss       = 20000;  // Stop Loss en points
input double TakeProfit     = 30000;  // Take Profit en points
input double MaxSpread      = 450;    // Ecart max autorisé en points

// Handles et buffers pour Heiken Ashi
int ha_handle;
double ha_open_buffer[], ha_close_buffer[], ha_high_buffer[], ha_low_buffer[];

// Handles et buffers pour Ichimoku
int ichimokuHandle;

// Variables pour RSI
int rsiHandle;

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
CTrade trade;
CPositionInfo position;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Vérification des paramètres d'entrée
   if(LotSize <= 0 || MagicNumber <= 0 || Slippage < 0 || StopLoss <= 0 || TakeProfit <= 0 || MaxSpread <= 0)
   {
      Print("Paramètres d'entrée invalides!");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Initialisation Heiken Ashi
   ha_handle = iCustom(_Symbol, _Period, "Examples\\Heiken_Ashi");
   if(ha_handle == INVALID_HANDLE)
   {
      Print("Échec de l'initialisation de Heiken Ashi!");
      return(INIT_FAILED);
   }

   // Initialisation du RSI
   rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("Échec de l'initialisation du RSI!");
      return(INIT_FAILED);
   }
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   // Configuration des séries temporelles
   ArraySetAsSeries(ha_open_buffer, true);
   ArraySetAsSeries(ha_close_buffer, true);
   ArraySetAsSeries(ha_high_buffer, true);
   ArraySetAsSeries(ha_low_buffer, true);
   
   // Création de l'indicateur Ichimoku
   ichimokuHandle = iIchimoku(_Symbol, PERIOD_CURRENT, 9, 26, 52);

   // Ajout de l'indicateur Ichimoku au graphique
   if(!ChartIndicatorAdd(0, 0, ichimokuHandle))
   {
         Print("Erreur : Impossible d'ajouter Ichimoku sur le graphique.");
   }

   Print("Expert Advisor initialisé avec succès!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(ha_handle != INVALID_HANDLE)
    {
        IndicatorRelease(ha_handle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   if(last_bar_time == current_bar_time) 
      return;
      
   last_bar_time = current_bar_time;

   ichimokuHandle = iIchimoku(_Symbol, PERIOD_CURRENT, 9, 26, 52);

   if(IsFridayEvening())
   {
      Print("🕛 Vendredi soir : Fermeture de toutes les positions !");
      CloseAllPositions();
   }
   if(IsAsianSession())
   {
      Print("🚫 Session asiatique en cours, pas de trading !");
      return; // Sort de la fonction sans exécuter d'ordres
   }

   CheckHeikenAshiSignals();
}

//+------------------------------------------------------------------+
//| Configuration pour le RSI                                        |
//+------------------------------------------------------------------+
double GetRSI()
{
    double rsiBuffer[];

    if(rsiHandle > 0)
    {
        if(CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) > 0)
        {
            Print("Valeur actuelle du RSI : ", rsiBuffer[0]); // Affichage du RSI
            return rsiBuffer[0]; // Retourne la valeur actuelle
        }
    }

    Print("❌ Erreur : Impossible de récupérer le RSI.");
    return 0; // Retourne 0 si erreur
}

string GetRSISignal()
{
    double rsi = GetRSI();

    if(rsi > 70)
    {
        Print("🚀 RSI élevé → Signal de VENTE !");
        return "SELL";
    }
    else if(rsi < 30)
    {
        Print("📈 RSI bas → Signal d'ACHAT !");
        return "BUY";
    }

    Print("⚖️ RSI neutre → Pas de signal.");
    return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Ichimoku Kynko Hyo                                               |
//+------------------------------------------------------------------+

string GetSignal()
{
    double kijunSen[], senkouA[], senkouB[], price;

    if (ichimokuHandle <= 0)
    {
        Print("❌ Erreur : handle Ichimoku non valide.");
        return "ERROR";
    }

    // Récupérer les buffers Ichimoku
    if (CopyBuffer(ichimokuHandle, 1, 0, 1, kijunSen) <= 0 ||
        CopyBuffer(ichimokuHandle, 3, 26, 1, senkouA) <= 0 || // décalage de 26 pour le nuage
        CopyBuffer(ichimokuHandle, 4, 26, 1, senkouB) <= 0)
    {
        Print("❌ Erreur : échec de la lecture des buffers Ichimoku.");
        return "ERROR";
    }

    price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Calcul des bornes du nuage
    double cloudTop = MathMax(senkouA[0], senkouB[0]);
    double cloudBottom = MathMin(senkouA[0], senkouB[0]);

    bool aboveCloud = price > cloudTop;
    bool belowCloud = price < cloudBottom;
    bool aboveKijun = price > kijunSen[0];
    bool belowKijun = price < kijunSen[0];

    // Signaux
    if (aboveKijun && aboveCloud)
    {
        Print("🟢 Prix au-dessus de la Kijun ET du Nuage → Signal **ACHAT**");
        return "BUY";
    }
    else if (belowKijun && belowCloud)
    {
        Print("🔴 Prix sous la Kijun ET sous le Nuage → Signal **VENTE**");
        return "SELL";
    }
    else
    {
        Print("⚠️ Pas de signal clair : prix dans ou proche du nuage.");
        return "NEUTRAL";
    }
}



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

   // Ichimoku Kynko Hyo
   string signal = GetSignal();
   string rsiSignal = GetRSISignal();
   
   if(PositionSelect(_Symbol))
   {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         hasLongPosition = true;
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         hasShortPosition = true;
   }

   // Signal d'achat - Deux bougies haussières consécutives
   if(ha_close_buffer[0] > ha_open_buffer[0] && 
      ha_close_buffer[1] > ha_open_buffer[1] && 
      ha_close_buffer[2] > ha_open_buffer[2] && 
      signal == "BUY" && rsiSignal == "NEUTRAL")
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
      signal == "SELL" && rsiSignal == "NEUTRAL")
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

//+------------------------------------------------------------------+
//| Ferme toutes les positions                                       |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
         {
               trade.PositionClose(position.Ticket());
               Print("Position fermée : Ticket #", position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Ouvrir une position d'achat                                      |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double stop_loss_price = ask - StopLoss * point;
   double take_profit_price = ask + TakeProfit * point;
   
   // Vérifier le solde disponible
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin < 0)
   {
      Print("Erreur : Marge insuffisante pour ouvrir une position d'achat.");
      return;
   }

   if(!trade.Buy(LotSize, _Symbol, ask, stop_loss_price, take_profit_price, "Achat Heiken Ashi"))
   {
      Print("Erreur lors de l'ouverture de la position d'achat : ", GetLastError());
   }
   else
   {
      Print("Position d'achat ouverte avec succès ! Prix: ", ask, " SL: ", stop_loss_price, " TP: ", take_profit_price);
   }
}

//+------------------------------------------------------------------+
//| Ouvrir une position de vente                                     |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double stop_loss_price = bid + StopLoss * point;
   double take_profit_price = bid - TakeProfit * point;
   
   // Vérifier le solde disponible
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin < 0)
   {
      Print("Erreur : Marge insuffisante pour ouvrir une position de vente.");
      return;
   }

   if(!trade.Sell(LotSize, _Symbol, bid, stop_loss_price, take_profit_price, "Vente Heiken Ashi"))
   {
      Print("Erreur lors de l'ouverture de la position de vente : ", GetLastError());
   }
   else
   {
      Print("Position de vente ouverte avec succès ! Prix: ", bid, " SL: ", stop_loss_price, " TP: ", take_profit_price);
   }
}



/* Eviter les expositions inutiles du capital */

//+------------------------------------------------------------------+
//| Eviter de trader la session asiatique                            |
//+------------------------------------------------------------------+
bool IsAsianSession()
{
   MqlDateTime timeStruct;
   TimeCurrent(timeStruct); // Obtient l'heure actuelle du serveur

   if(timeStruct.hour >= 0 && timeStruct.hour < 7) // Session asiatique (00:00 - 08:00 UTC)
   {   
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions vendredis                            |
//+------------------------------------------------------------------+
bool IsFridayEvening()
{
   MqlDateTime timeStruct;
   TimeCurrent(timeStruct);

   if(timeStruct.day_of_week == 5 && timeStruct.hour >= 20) // Vendredi après 22h
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Eviter le trading de News                                        |
//+------------------------------------------------------------------+