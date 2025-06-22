//+------------------------------------------------------------------+
//|                                                    Clement12.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Paramètres globaux / variables d'entrées                         |
//+------------------------------------------------------------------+

input double LotSize = 1.0; //Taille de lot
input double StopLoss = 20000; //Niveau de stopLoss
input double TakeProfit = 20700; // Niveau de TakeProfit
input int MagicNumber = 123456; // Identifiant unique des des trades
input int MaxSpread = 450; // Spread maximum autorisé
input int RSI_Period = 24; // Période de l'indicateur RSI
input int RSI_Overbought = 70; // Niveau de surachat pour le RSI
input int RSI_Oversold = 30; // Niveau de survente pour le RSI

//+------------------------------------------------------------------+
//|  Variables globales                                              |
//+------------------------------------------------------------------+
double HA_Open, HA_Close, HA_High, HA_Low;

// Récupération des valeurs Heiken Ashi
void GetHeikenAshiValues()
{
    HA_Open  = iCustom(_Symbol, PERIOD_CURRENT, "Heiken Ashi", 0, 0);
    HA_Close = iCustom(_Symbol, PERIOD_CURRENT, "Heiken Ashi", 3, 0);
    HA_High  = iCustom(_Symbol, PERIOD_CURRENT, "Heiken Ashi", 1, 0);
    HA_Low   = iCustom(_Symbol, PERIOD_CURRENT, "Heiken Ashi", 2, 0);
}

double Fib_Level_0, Fib_Level_23, Fib_Level_38, Fib_Level_50, Fib_Level_61, Fib_Level_100;

// Calcul des niveaux Fibonacci natifs
void GetFibonacciLevels()
{
    double lastHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double lastLow = iLow(_Symbol, PERIOD_CURRENT, 0);

    Fib_Level_23 = lastLow + (lastHigh - lastLow) * 0.23;
    Fib_Level_38 = lastLow + (lastHigh - lastLow) * 0.38;
    Fib_Level_50 = lastLow + (lastHigh - lastLow) * 0.50;
    Fib_Level_61 = lastLow + (lastHigh - lastLow) * 0.61;
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+


