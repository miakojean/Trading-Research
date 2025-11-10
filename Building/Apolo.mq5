//+------------------------------------------------------------------+
//|                                               CaladriusTears.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//|  variables globales                                              |
//+------------------------------------------------------------------+
// Identifiants pour les objets graphiques du range
#define OBJ_RANGE_RESISTANCE "RangeResistanceLine"
#define OBJ_RANGE_SUPPORT    "RangeSupportLine"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input double LotSize        = 0.5;      // Taille du lot
input int    MagicNumber    = 12345;  // Magic Number
input int    Slippage       = 3;      // Slippage en points
input double StopLoss       = 30000;  // Stop Loss en points
input double TakeProfit     = 50000;  // Take Profit en points
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
#include <Arrays\ArrayObj.mqh> // Pour utiliser CArrayObj
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

   if(IsFridayEvening())
   {
      Print("🕛 Vendredi soir : Fermeture de toutes les positions !");
      CloseAllPositions();
   }

   SystemSignals();
   // Gérer les Stop Loss des positions existantes
   ManageStopLoss(); // <--- Appelez votre nouvelle fonction ici
   IsMarketRangingRelativeAmplitude();

   double capital = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("Solde actuel du compte : ", capital);
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
   double kijunSen[], price;

   if(ichimokuHandle > 0) // Vérification que l'indicateur est bien chargé
   {
      if(CopyBuffer(ichimokuHandle, 1, 0, 1, kijunSen) > 0)
      {
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Prix actuel
         
         // Vérification des conditions de signal
         if(price > kijunSen[0])
         {
            Print("🔹 Le prix est **au-dessus** de la Kijun-Sen → Signal ACHAT !");
            return "BUY";
         }
         else if(price < kijunSen[0])
         {
            Print("🔻 Le prix est **en dessous** de la Kijun-Sen → Signal VENTE !");
            return "SELL";
         }
         else
         {
            Print("⚖️ Le prix est **exactement** sur la Kijun-Sen → Pas de signal.");
            return "NEUTRAL";
         }

      }
   }

   Print("❌ Erreur : Impossible de récupérer la Kijun-Sen.");
   return "ERROR"; // Retourne "ERROR" en cas de problème
}

// Get KumoPosition

string GetKumoPosition()
{
   double senkouSpanA[], senkouSpanB[], price;
   int shift = 26; // Le décalage standard du nuage Ichimoku

   if(ichimokuHandle > 0)
   {
      if(CopyBuffer(ichimokuHandle, 2, shift, 1, senkouSpanA) > 0 &&
         CopyBuffer(ichimokuHandle, 3, shift, 1, senkouSpanB) > 0)
      {
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         double upper = MathMax(senkouSpanA[0], senkouSpanB[0]);
         double lower = MathMin(senkouSpanA[0], senkouSpanB[0]);

         if(price > upper)
         {
            Print("☁️ Le prix est **au-dessus** du nuage → Biais haussier !");
            return "ABOVE_CLOUD";
         }
         else if(price < lower)
         {
            Print("☁️ Le prix est **en dessous** du nuage → Biais baissier !");
            return "BELOW_CLOUD";
         }
         else
         {
            Print("🌫️ Le prix est **dans** le nuage → Zone d'incertitude.");
            return "INSIDE_CLOUD";
         }
      }
   }

   Print("❌ Erreur : Impossible de récupérer les lignes du nuage.");
   return "ERROR";
}

//+------------------------------------------------------------------+
//| Détecte un range basé sur l'amplitude relative à la moyenne      |
//+------------------------------------------------------------------+
bool IsMarketRangingRelativeAmplitude()
{
    // Paramètres
    int    InpRangeLookbackBars = 50;     // Barres pour analyser le range actuel
    int    InpHistoricalBars = 200;       // Barres pour calculer l'amplitude historique
    double InpRangeAmplitudeRatio = 0.1;  // Ratio max (50%) entre amplitude actuelle et historique
    
    Print("===== Début analyse IsMarketRangingRelativeAmplitude =====");
    Print("Paramètres: Lookback=", InpRangeLookbackBars, " bars, HistoricalBars=", InpHistoricalBars, ", RatioMax=", InpRangeAmplitudeRatio*100, "%");

    // Vérification des données disponibles
    int availableBars = Bars(_Symbol, _Period);
    if (availableBars < InpHistoricalBars)
    {
        Print("Échec: Seulement ", availableBars, " barres disponibles (", InpHistoricalBars, " requises)");
        Print("===== Fin analyse (FALSE) =====");
        return false;
    }
    Print("Barres disponibles: ", availableBars, " (OK)");

    // 1. Calcul de l'amplitude actuelle
    double currentHigh = iHighest(_Symbol, _Period, MODE_HIGH, InpRangeLookbackBars, 0);
    double currentLow = iLowest(_Symbol, _Period, MODE_LOW, InpRangeLookbackBars, 0);
    double currentAmplitude = currentHigh - currentLow;
    Print("Amplitude actuelle (", InpRangeLookbackBars, " barres): ", currentAmplitude);

    // 2. Calcul de l'amplitude historique moyenne
    double historicalAmplitudeSum = 0;
    for(int i = 0; i < InpHistoricalBars; i++)
    {
        double barHigh = iHigh(_Symbol, _Period, i);
        double barLow = iLow(_Symbol, _Period, i);
        historicalAmplitudeSum += (barHigh - barLow);
    }
    double avgHistoricalAmplitude = historicalAmplitudeSum / InpHistoricalBars;
    Print("Amplitude historique moyenne (", InpHistoricalBars, " barres): ", avgHistoricalAmplitude);

    // 3. Calcul du ratio amplitude actuelle/historique
    double amplitudeRatio = currentAmplitude / avgHistoricalAmplitude;
    Print("Ratio amplitude actuelle/historique: ", amplitudeRatio*100, "%");

    // Condition: le ratio doit être <= 50%
    if(amplitudeRatio <= InpRangeAmplitudeRatio)
    {
        Print("Condition RANGE: VRAI (Ratio ", amplitudeRatio*100, "% <= ", InpRangeAmplitudeRatio*100, "%)");
        Print("===== Fin analyse (TRUE) =====");
        return true;
    }
    else
    {
        Print("Condition RANGE: FAUX (Ratio ", amplitudeRatio*100, "% > ", InpRangeAmplitudeRatio*100, "%)");
        Print("===== Fin analyse (FALSE) =====");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Les différents signaux du système de tradding                    |
//+------------------------------------------------------------------+
void SystemSignals()
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
        signal == "SELL" && rsiSignal == "NEUTRAL" && isAsianSession == false
        )
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

    double dynamicLotSize = AdjustLotSize();
    
    // Vérifier le solde disponible
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(freeMargin < 0)
    {
        Print("Erreur : Marge insuffisante pour ouvrir une position d'achat.");
        return;
    }

    if(!trade.Buy(dynamicLotSize, _Symbol, ask, stop_loss_price, take_profit_price, "Achat Heiken Ashi"))
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

    double dynamicLotSize = AdjustLotSize();
    
    // Vérifier le solde disponible
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(freeMargin < 0)
    {
        Print("Erreur : Marge insuffisante pour ouvrir une position de vente.");
        return;
    }

    if(!trade.Sell(dynamicLotSize, _Symbol, bid, stop_loss_price, take_profit_price, "Vente Heiken Ashi"))
    {
        Print("Erreur lors de l'ouverture de la position de vente : ", GetLastError());
    }
    else
    {
        Print("Position de vente ouverte avec succès ! Prix: ", bid, " SL: ", stop_loss_price, " TP: ", take_profit_price);
    }
}

/* La gestion du risque; partie la plus importante de notre système */

//+------------------------------------------------------------------+
//| Gestion simple de la taille de position                          |
//+------------------------------------------------------------------+
double AdjustLotSize()
{
    // Obtenir les contraintes de volume du courtier pour le symbole actuel
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double ReduceLossFactor = 2.0; // Facteur de réduction si la dernière position était perdante (par défaut 2x moins)

    // --- Étape 1 : Valider et normaliser la LotSize d'entrée ---
    double baseValidatedLot = LotSize;
    baseValidatedLot = MathMax(baseValidatedLot, minLot);
    baseValidatedLot = MathMin(baseValidatedLot, maxLot);
    baseValidatedLot = NormalizeDouble(baseValidatedLot / stepLot, 0) * stepLot;

    // Cette variable contiendra la taille de lot finale
    double finalLotSize = baseValidatedLot; 
    
    // Obtenir les signaux Ichimoku et la position par rapport au nuage
    string signal = GetSignal();
    string kumoPosition = GetKumoPosition();
    
    // Déterminer le type d'ordre pour la condition de doublement
    ENUM_ORDER_TYPE orderType;
    if (signal == "BUY")
    {
        orderType = ORDER_TYPE_BUY;
    }
    else if (signal == "SELL")
    {
        orderType = ORDER_TYPE_SELL;
    }
    else
    {
        Print("ℹ️ Signal Ichimoku neutre ou erreur. Utilisation de la LotSize de base validée : ", finalLotSize);
        return finalLotSize; 
    }

    // --- Vérifier si la dernière position était perdante et ajuster le lot en conséquence ---
    if (WasLastPositionLoss())
    {
        // Réduire le lot de base par le facteur de réduction (par exemple, diviser par 2)
        finalLotSize = baseValidatedLot / ReduceLossFactor;
        Print("📉 La dernière position était perdante. Réduction du lot à : ", finalLotSize);
    }
    // Si la dernière position n'était PAS perdante, on peut envisager le doublement.
    // NOTE : Si vous voulez que la réduction annule le doublement, ou que le doublement annule la réduction,
    // l'ordre de ces blocs 'if' est important. Ici, la réduction prime sur le doublement.
    else 
    {
        // --- Logique de doublement du lot si les conditions du Kumo sont remplies ---
        bool shouldDoubleLot = false;
        if ((orderType == ORDER_TYPE_BUY && kumoPosition == "ABOVE_CLOUD") || 
            (orderType == ORDER_TYPE_SELL && kumoPosition == "BELOW_CLOUD"))
        {
            shouldDoubleLot = true;
        }

        if (shouldDoubleLot)
        {
            // Doubler la taille de lot de base (non réduite)
            finalLotSize = baseValidatedLot * 2.0;
            Print("🚀 Doublé la taille de lot de base en raison de la position favorable du nuage Ichimoku.");
        }
        else
        {
            // Si aucune condition spéciale, on garde la taille de lot de base
            Print("ℹ️ Utilisation de la taille de lot de base.");
        }
    }

    // --- Valider et normaliser la taille de lot finale ---
    finalLotSize = MathMax(finalLotSize, minLot); // Ne pas être inférieur au min
    finalLotSize = MathMin(finalLotSize, maxLot); // Ne pas être supérieur au max
    finalLotSize = NormalizeDouble(finalLotSize / stepLot, 0) * stepLot;

    // --- Vérification finale ---
    if (finalLotSize <= 0)
    {
        Print("⚠️ La taille de lot finale est nulle ou négative après ajustements. Retourne le volume minimum autorisé ou 0.1.");
        return MathMax(minLot, 0.1); 
    }

    Print("✅ Taille de lot finale déterminée : ", finalLotSize);
    return finalLotSize;
}

//+------------------------------------------------------------------------------+
//| Nouvelle fonction pour vérifier le résultat de la dernière position clôturée |
//+------------------------------------------------------------------------------+
bool WasLastPositionLoss()
{
    // Sélectionner toutes les positions dans l'historique pour le symbole actuel et le Magic Number
    // et trier par heure de clôture descendante
    HistorySelect(0, TimeCurrent());
    
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if (deal_ticket == 0) continue;

        if (HistoryDealGetString(deal_ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) // C'est une sortie de position (clôture)
        {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            if (profit < 0)
            {
                // La dernière position clôturée pour cet EA/symbole était une perte
                Print("🔍 Dernière position clôturée pour ", _Symbol, " (Magic: ", MagicNumber, ") était une PERTE (Profit: ", profit, ").");
                return true;
            }
            else
            {
                // La dernière position clôturée était un gain ou un point mort.
                Print("🔍 Dernière position clôturée pour ", _Symbol, " (Magic: ", MagicNumber, ") était un GAIN/Point Mort (Profit: ", profit, ").");
                return false; // On a trouvé une position, et elle n'était pas perdante
            }
        }
    }
    // Si aucune position clôturée n'est trouvée pour cet EA/symbole, on considère que la dernière n'était pas perdante.
    // Ou vous pouvez choisir de retourner false et de ne pas réduire le lot par défaut.
    Print("🔍 Aucune position clôturée trouvée pour ", _Symbol, " (Magic: ", MagicNumber, ").");
    return false; 
}

//+------------------------------------------------------------------+
//| Gère le Stop Loss des positions ouvertes                         |
//+------------------------------------------------------------------+
void ManageStopLoss()
{
    // Itérer sur toutes les positions du compte
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        // Sélectionner la position par index
        if (position.SelectByIndex(i))
        {
            // Vérifier si la position appartient à cet EA et à ce symbole
            if (position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            {
                double currentSL = position.StopLoss(); // Stop Loss actuel de la position
                double entryPrice = position.PriceOpen(); // Prix d'ouverture de la position
                double currentProfit = position.Profit(); // Profit/Perte actuel de la position
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                double newSL = -3000; // Nouvelle valeur du Stop Loss à calculer

                // --- Logique de gestion du Stop Loss ---

                // Exemple 1 : Remonter le Stop Loss au point mort (Break-even)
                // Si le profit dépasse X points, remonte le SL au prix d'entrée + un petit surplus pour les frais
                int breakEvenPoints = 10000; // Par exemple, 500 points de profit pour activer le Break-even
                int breakEvenBufferPoints = 10; // Marge pour couvrir le spread/commission

                if (position.PositionType() == POSITION_TYPE_BUY)
                {
                    if (bid > entryPrice + breakEvenPoints * point) // Si la position est en profit suffisant
                    {
                        newSL = entryPrice + breakEvenBufferPoints * point;
                        // Assurez-vous que le nouveau SL n'est pas pire que l'actuel et qu'il est supérieur au prix d'entrée
                        if (newSL > currentSL || currentSL == 0) // currentSL == 0 signifie pas de SL défini initialement
                        {
                            if (trade.PositionModify(position.Ticket(), newSL, position.TakeProfit()))
                            {
                                Print("✅ SL d'achat ajusté au point mort pour le ticket #", position.Ticket(), ". Nouveau SL: ", newSL);
                            }
                            else
                            {
                                Print("❌ Échec de l'ajustement du SL d'achat pour le ticket #", position.Ticket(), ": ", GetLastError());
                            }
                        }
                    }
                }
                else if (position.PositionType() == POSITION_TYPE_SELL)
                {
                    if (ask < entryPrice - breakEvenPoints * point) // Si la position est en profit suffisant
                    {
                        newSL = entryPrice - breakEvenBufferPoints * point;
                        // Assurez-vous que le nouveau SL n'est pas pire que l'actuel et qu'il est inférieur au prix d'entrée
                        if (newSL < currentSL || currentSL == 0)
                        {
                            if (trade.PositionModify(position.Ticket(), newSL, position.TakeProfit()))
                            {
                                Print("✅ SL de vente ajusté au point mort pour le ticket #", position.Ticket(), ". Nouveau SL: ", newSL);
                            }
                            else
                            {
                                Print("❌ Échec de l'ajustement du SL de vente pour le ticket #", position.Ticket(), ": ", GetLastError());
                            }
                        }
                    }
                }
                
            }
        }
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