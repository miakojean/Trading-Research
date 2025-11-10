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
input double LotSize        = 1;     // Taille du lot
input int    MagicNumber    = 12345;   // Magic Number
input int    Slippage       = 3;       // Slippage en points
input double StopLoss       = 20500;      // Stop Loss en points
input double TakeProfit     = 20000;     // Take Profit en points
input double MaxSpread      = 450;       // Ecart max autorisé en points

// Handles et buffers pour Heiken Ashi et Ichimoku
int ha_handle;
double ha_open_buffer[], ha_close_buffer[], ha_high_buffer[], ha_low_buffer[];
int ichimoku_handle;

#include <Trade\Trade.mqh>
CTrade trade;

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
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    ArraySetAsSeries(ha_open_buffer, true);
    ArraySetAsSeries(ha_close_buffer, true);
    ArraySetAsSeries(ha_high_buffer, true);
    ArraySetAsSeries(ha_low_buffer, true);
    Print("Heiken Ashi initialized successfully!");

    // Initialisation des buffers Ichimoku
    ichimoku_handle = iIchimoku(_Symbol, _Period, 9, 26, 52);
    if(ichimoku_handle == INVALID_HANDLE)
    {
        Print("Échec de l'initialisation d'Ichimoku!");
        return(INIT_FAILED);
    }

    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    
    // Configuration des séries temporelles
    ArraySetAsSeries(ha_open_buffer, true);
    ArraySetAsSeries(ha_close_buffer, true);
    ArraySetAsSeries(ha_high_buffer, true);
    ArraySetAsSeries(ha_low_buffer, true);

    Print("Indicateurs initialisés avec succès!");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason){

    if(ha_handle != INVALID_HANDLE){
        IndicatorRelease(ha_handle);
    }
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(_Symbol, _Period, 0);

    if(last_bar_time == current_bar_time) return;
    last_bar_time = current_bar_time;

    CheckHeikenAshiSignals();
    
}

void CheckHeikenAshiSignals()
{
    // Récupération Heiken Ashi - DOIT ÊTRE FAIT EN PREMIER
    if(CopyBuffer(ha_handle, 0, 0, 3, ha_open_buffer) < 3 ||
       CopyBuffer(ha_handle, 1, 0, 3, ha_high_buffer) < 3 ||
       CopyBuffer(ha_handle, 2, 0, 3, ha_low_buffer) < 3 ||
       CopyBuffer(ha_handle, 3, 0, 3, ha_close_buffer) < 3) 
    {
        Print("⚠️ Échec de la copie des valeurs Heiken Ashi !");
        return;
    }

    // MAINTENANT on peut vérifier les valeurs
    if(ArraySize(ha_open_buffer) < 3) 
    {
        Print("⚠️ Erreur : Pas assez de données dans les buffers !");
        return;
    }

    // Prévisualisation des signaux de renversement
    if (ha_close_buffer[1] > ha_open_buffer[1] && ha_close_buffer[2] < ha_open_buffer[2]) 
    {
        Print("🔄 Signal de renversement haussier potentiel - Bougie haussière après une bougie baissière");
    }
    else if (ha_close_buffer[1] < ha_open_buffer[1] && ha_close_buffer[2] > ha_open_buffer[2]) 
    {
        Print("🔄 Signal de renversement baissier potentiel - Bougie baissière après une bougie haussière");
    }

    // Vérification des signaux
    if(ha_close_buffer[1] > ha_open_buffer[1] && ha_close_buffer[2] > ha_open_buffer[2]) 
    {
        Print("🔹 Signal ACHAT - Deux bougies bleues consécutives");
        // Ici vous ajouteriez la logique d'achat réelle
    }
    else if(ha_close_buffer[1] < ha_open_buffer[1] && ha_close_buffer[2] < ha_open_buffer[2]) 
    {
        Print("🔻 Signal VENTE - Deux bougies rouges consécutives");
        // Ici vous ajouteriez la logique de vente réelle
    }
}

//+------------------------------------------------------------------+
