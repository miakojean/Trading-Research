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
//| Gestion dynamique de la taille de position                       |
//+------------------------------------------------------------------+
double AdjustLotSize()
{
    // Taille du lot par défaut, utilisée si aucune condition d'ajustement spécifique n'est remplie
    double calculatedLotSize = LotSize; 
    
    // Obtenir la marge libre disponible sur le compte
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    // Récupérer les signaux Ichimoku et la position par rapport au nuage
    string signal = GetSignal();
    string kumoPosition = GetKumoPosition();
    
    // Déterminer le type d'ordre et le prix pour le calcul de marge
    // Cette partie doit être robuste même si les signaux ne sont pas BUY/SELL
    ENUM_ORDER_TYPE orderType;
    double price;
    
    if (signal == "BUY")
    {
        orderType = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    else if (signal == "SELL")
    {
        orderType = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }
    else
    {
        // Si le signal est neutre ou erreur, on ne peut pas calculer la marge pour une nouvelle transaction,
        // donc on s'en tient au lot par défaut.
        Print("ℹ️ Signal Ichimoku neutre ou erreur, pas de calcul de lot dynamique avancé. Utilisation du LotSize par défaut.");
        return calculatedLotSize; 
    }

    double marginRequiredForOneLot;
    // Calculer la marge requise pour 1.0 lot. Vérifier si le calcul réussit.
    if (!OrderCalcMargin(orderType, _Symbol, 1.0, price, marginRequiredForOneLot))
    {
        Print("❌ Erreur lors du calcul de la marge requise pour 1.0 lot : ", GetLastError(), ". Utilisation du LotSize par défaut.");
        return calculatedLotSize; // Retourne le lot par défaut en cas d'échec du calcul
    }
    
    // --- Logique de gestion du risque dynamique ---

    // Option 1: Doublement du lot si les conditions du nuage Ichimoku sont très favorables
    // Ceci peut être appliqué à la première position si l'on veut être plus agressif dès le début.
    bool canDoubleLot = false;
    if ((orderType == ORDER_TYPE_BUY && kumoPosition == "ABOVE_CLOUD") || 
        (orderType == ORDER_TYPE_SELL && kumoPosition == "BELOW_CLOUD"))
    {
        canDoubleLot = true;
    }
    
    if (canDoubleLot)
    {
        // On vise à utiliser un certain pourcentage de la marge libre pour le lot doublé
        // Par exemple, 5% du solde du compte ou un pourcentage de la marge libre.
        // Ici, nous allons calculer un lot maximum basé sur un pourcentage de la marge libre disponible.
        // C'est plus sûr que de simplement doubler le lot sans vérification de la marge.
        
        // Pourcentage de marge libre que nous sommes prêts à risquer pour cette position (ex: 10%)
        // Ajustez cette valeur selon votre tolérance au risque.
        double percentageOfFreeMarginToUse = 0.10; 
        
        // Lot maximal que l'on peut ouvrir avec ce pourcentage de marge libre
        double maxAllowedLotBasedOnMargin = (freeMargin * percentageOfFreeMarginToUse) / marginRequiredForOneLot;
        
        // Limiter le lot minimum, maximum et les pas du symbole
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        // Calculer le lot doublé potentiel (si une position existe déjà et qu'on voulait doubler)
        // Sinon, c'est simplement LotSize * 2.0 pour la première position si canDoubleLot est vrai
        double proposedLot = LotSize * 2.0; // Point de départ pour le lot "doublé"

        // Vérifier si une position existe déjà et ajuster le 'proposedLot' en conséquence
        if (PositionSelect(_Symbol))
        {
             double currentLot = PositionGetDouble(POSITION_VOLUME);
             // Si on veut vraiment doubler une position existante
             proposedLot = currentLot * 2.0; 
        }

        // Le lot final sera le minimum entre le lot proposé (doublé ou LotSize*2),
        // le lot maximal autorisé par la marge et le lot maximum du symbole.
        calculatedLotSize = MathMin(proposedLot, maxAllowedLotBasedOnMargin);
        calculatedLotSize = MathMin(calculatedLotSize, maxLot); // S'assurer de ne pas dépasser le lot max du symbole
        calculatedLotSize = MathMax(calculatedLotSize, minLot); // S'assurer de ne pas être en dessous du lot min

        // Normaliser le lot à l'étape de volume du symbole
        calculatedLotSize = NormalizeDouble(calculatedLotSize / stepLot, 0) * stepLot;

        Print("🚀 Lot dynamique calculé : ", calculatedLotSize, " (basé sur le signal et la marge).");
    }
    else
    {
        // Si les conditions de doublement ne sont pas remplies, ou si c'est la première position sans conditions spéciales,
        // on utilise le LotSize par défaut.
        calculatedLotSize = LotSize;

        // Assurez-vous que le LotSize par défaut est également valide
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
        calculatedLotSize = MathMax(calculatedLotSize, minLot);
        calculatedLotSize = MathMin(calculatedLotSize, maxLot);
        calculatedLotSize = NormalizeDouble(calculatedLotSize / stepLot, 0) * stepLot;

        Print("ℹ️ Utilisation du LotSize par défaut : ", calculatedLotSize);
    }

    // Vérification finale pour s'assurer que le lot n'est pas zéro ou négatif.
    if (calculatedLotSize <= 0)
    {
        Print("⚠️ Le calcul du lot a résulté en une valeur invalide (<= 0). Retourne le LotSize par défaut.");
        return LotSize; // Fallback au LotSize d'entrée si le calcul a foiré.
    }

    return calculatedLotSize;
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