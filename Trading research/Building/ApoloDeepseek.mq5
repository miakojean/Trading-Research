//+------------------------------------------------------------------+
//|                                                      CaladriusTears_Optimized.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input double RiskPercent      = 1.0;    // Risque par trade (% du capital)
input int    MagicNumber      = 12345;  // Magic Number
input int    Slippage         = 3;      // Slippage en points
input int    ATR_Period       = 14;     // Période ATR
input double SL_Multiplier    = 1.5;    // Multiplicateur SL
input double TP_Multiplier    = 2.0;    // Multiplicateur TP
input double MaxSpread        = 450;    // Ecart max autorisé en points
input bool   UseTrendFilter   = true;   // Filtre de tendance H4

// Handles et buffers
int ha_handle, ichimokuHandle, rsiHandle, atrHandle;
double ha_open[], ha_close[], ha_high[], ha_low[];
double rsiBuffer[], kijunSen[], tenkanSen[], atrBuffer[];

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
CTrade trade;
CPositionInfo position;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Vérification des paramètres
    if(RiskPercent <= 0 || RiskPercent > 5) {
        Alert("RiskPercent doit être entre 0.1 et 5");
        return(INIT_PARAMETERS_INCORRECT);
    }

    // Initialisation des indicateurs
    ha_handle = iCustom(_Symbol, _Period, "Examples\\Heiken_Ashi");
    rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    atrHandle = iATR(_Symbol, _Period, ATR_Period);
    ichimokuHandle = iIchimoku(_Symbol, _Period, 9, 26, 52);

    if(ha_handle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || 
       atrHandle == INVALID_HANDLE || ichimokuHandle == INVALID_HANDLE) {
        Alert("Erreur d'initialisation des indicateurs");
        return(INIT_FAILED);
    }

    // Configuration des séries temporelles
    ArraySetAsSeries(ha_open, true);
    ArraySetAsSeries(ha_close, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(kijunSen, true);
    ArraySetAsSeries(atrBuffer, true);

    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    
    Print("EA initialisé avec succès");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    
    if(lastBarTime == currentBarTime) return;
    lastBarTime = currentBarTime;

    // Fermeture vendredi soir
    if(IsFridayEvening()) {
        CloseAllPositions();
        return;
    }

    // Vérification des spreads
    double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(spread > MaxSpread) return;

    // Calcul dynamique du risque
    double atr = GetATR();
    double stopLoss = atr * SL_Multiplier;
    double takeProfit = atr * TP_Multiplier;
    double lotSize = CalculateLotSize(stopLoss);

    // Récupération des signaux
    string signal = GetCombinedSignal();
    
    // Gestion des positions
    if(signal == "BUY" && !HasPosition(POSITION_TYPE_BUY)) {
        OpenPosition(ORDER_TYPE_BUY, lotSize, stopLoss, takeProfit);
    }
    else if(signal == "SELL" && !HasPosition(POSITION_TYPE_SELL)) {
        OpenPosition(ORDER_TYPE_SELL, lotSize, stopLoss, takeProfit);
    }

    // Gestion partielle des profits
    ManagePartialCloses(0.5); // Ferme 50% à 50% du TP
}

//+------------------------------------------------------------------+
//| Fonctions optimisées                                             |
//+------------------------------------------------------------------+

string GetCombinedSignal()
{
    // Récupération des données
    if(!GetIndicatorBuffers()) return "NEUTRAL";
    
    // Filtre de tendance
    if(UseTrendFilter) {
        double ma200 = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_SMA, PRICE_CLOSE, 1);
        if(ha_close[0] > ma200 && ha_close[1] > ma200 && kijunSen[0] > kijunSen[1]) {
            // Tendance haussière - privilégier les achats
            if(ha_close[0] > ha_open[0] && ha_close[1] > ha_open[1] && rsiBuffer[0] > 50)
                return "BUY";
        }
        else if(ha_close[0] < ma200 && ha_close[1] < ma200 && kijunSen[0] < kijunSen[1]) {
            // Tendance baissière - privilégier les ventes
            if(ha_close[0] < ha_open[0] && ha_close[1] < ha_open[1] && rsiBuffer[0] < 50)
                return "SELL";
        }
    }
    else {
        // Logique de base sans filtre de tendance
        if(ha_close[0] > kijunSen[0] && ha_close[0] > ha_open[0] && rsiBuffer[0] < 70)
            return "BUY";
        else if(ha_close[0] < kijunSen[0] && ha_close[0] < ha_open[0] && rsiBuffer[0] > 30)
            return "SELL";
    }
    
    return "NEUTRAL";
}

bool GetIndicatorBuffers()
{
    return (CopyBuffer(ha_handle, 0, 0, 3, ha_open) > 0 &&
           CopyBuffer(ha_handle, 3, 0, 3, ha_close) > 0 &&
           CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) > 0 &&
           CopyBuffer(ichimokuHandle, 1, 0, 2, kijunSen) > 0 &&
           CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0;
}

double GetATR()
{
    return atrBuffer[0];
}

double CalculateLotSize(double stopLossPoints)
{
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;
    return NormalizeDouble(riskAmount / (stopLossPoints * tickValue), 2);
}

void OpenPosition(ENUM_ORDER_TYPE type, double lots, double sl, double tp)
{
    double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double slPrice = (type == ORDER_TYPE_BUY) ? price - sl : price + sl;
    double tpPrice = (type == ORDER_TYPE_BUY) ? price + tp : price - tp;

    if(type == ORDER_TYPE_BUY) {
        trade.Buy(lots, _Symbol, price, slPrice, tpPrice, "Achat optimisé");
    }
    else {
        trade.Sell(lots, _Symbol, price, slPrice, tpPrice, "Vente optimisée");
    }
}

void ManagePartialCloses(double ratio)
{
    for(int i = PositionsTotal()-1; i >= 0; i--) {
        if(position.SelectByIndex(i) && position.Magic() == MagicNumber) {
            double profit = position.Profit();
            double tp = MathAbs(position.TakeProfit() - position.PriceOpen());
            
            if(profit >= (tp * ratio)) {
                double closeVolume = NormalizeDouble(position.Volume() * ratio, 2);
                trade.PositionClosePartial(position.Ticket(), closeVolume);
            }
        }
    }
}

bool HasPosition(ENUM_POSITION_TYPE posType)
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(position.SelectByIndex(i) && 
           position.Symbol() == _Symbol && 
           position.Magic() == MagicNumber &&
           position.PositionType() == posType) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                            |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal()-1; i >= 0; i--) {
        if(position.SelectByIndex(i) && position.Magic() == MagicNumber) {
            trade.PositionClose(position.Ticket());
        }
    }
}

bool IsFridayEvening()
{
    MqlDateTime timeNow;
    TimeCurrent(timeNow);
    return (timeNow.day_of_week == 5 && timeNow.hour >= 20);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(ha_handle);
    IndicatorRelease(rsiHandle);
    IndicatorRelease(atrHandle);
    IndicatorRelease(ichimokuHandle);
}