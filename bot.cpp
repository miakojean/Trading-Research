//+------------------------------------------------------------------+
//|                                                      Scalper.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"

// Paramètres d'entrée
input int      BB_Period = 20;          // Période des Bandes de Bollinger
input double   BB_Deviation = 2.0;      // Déviation standard
input double   LotSize = 0.1;           // Taille du lot
input int      TakeProfit = 15;         // Take Profit en points
input int      StopLoss = 10;           // Stop Loss en points
input int      Slippage = 3;            // Slippage autorisé
input int      MagicNumber = 123456;    // Magic Number pour identifier les trades
input double   RiskPercent = 1.0;       // Pourcentage du capital à risquer

// Variables globales
int BB_Handle;                          // Handle de l'indicateur Bollinger Bands
double BB_Upper[], BB_Lower[], BB_Middle[]; // Tableaux pour stocker les valeurs des bandes
datetime LastBarTime;                    // Temps de la dernière barre traitée

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation de l'indicateur Bollinger Bands
   BB_Handle = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   
   if(BB_Handle == INVALID_HANDLE)
   {
      Print("Échec de la création de l'indicateur Bollinger Bands");
      return(INIT_FAILED);
   }
   
   // Vérification des paramètres
   if(LotSize <= 0 || TakeProfit <= 0 || StopLoss <= 0)
   {
      Print("Paramètres incorrects");
      return(INIT_FAILED);
   }
   
   // Initialisation du temps de la dernière barre
   LastBarTime = iTime(_Symbol, _Period, 0);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libération de l'handle de l'indicateur
   if(BB_Handle != INVALID_HANDLE)
      IndicatorRelease(BB_Handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérification si c'est une nouvelle barre
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(currentTime == LastBarTime)
      return; // Pas de nouvelle barre, on sort
   
   LastBarTime = currentTime; // Mise à jour du temps de la dernière barre
   
   // Récupération des données des Bandes de Bollinger
   if(CopyBuffer(BB_Handle, 0, 0, 3, BB_Middle) != 3 || 
      CopyBuffer(BB_Handle, 1, 0, 3, BB_Upper) != 3 || 
      CopyBuffer(BB_Handle, 2, 0, 3, BB_Lower) != 3)
   {
      Print("Échec de la copie des données des Bandes de Bollinger");
      return;
   }
   
   // Récupération des prix actuels
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lastClose = iClose(_Symbol, _Period, 1);
   
   // Vérification des conditions d'achat (prix touche la bande inférieure)
   if(lastClose <= BB_Lower[1] && bid > BB_Lower[1])
   {
      CloseAllPositions(POSITION_TYPE_SELL); // Fermer les positions de vente
      if(!HasOpenPosition(POSITION_TYPE_BUY))
         OpenPosition(ORDER_TYPE_BUY);
   }
   // Vérification des conditions de vente (prix touche la bande supérieure)
   else if(lastClose >= BB_Upper[1] && ask < BB_Upper[1])
   {
      CloseAllPositions(POSITION_TYPE_BUY); // Fermer les positions d'achat
      if(!HasOpenPosition(POSITION_TYPE_SELL))
         OpenPosition(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Ouvre une position                                               |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * _Point : price + StopLoss * _Point;
   double tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * _Point : price - TakeProfit * _Point;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
   {
      Print("Échec de l'ouverture de la position. Code d'erreur: ", GetLastError());
   }
   else
   {
      Print("Position ouverte avec succès. Ticket: ", result.deal);
   }
}

//+------------------------------------------------------------------+
//| Vérifie s'il y a une position ouverte du type spécifié           |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetInteger(POSITION_TYPE) == positionType)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions du type spécifié                      |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetInteger(POSITION_TYPE) == positionType)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         request.deviation = Slippage;
         request.magic = MagicNumber;
         request.type_filling = ORDER_FILLING_FOK;
         
         if(!OrderSend(request, result))
         {
            Print("Échec de la fermeture de la position. Ticket: ", ticket, " Code d'erreur: ", GetLastError());
         }
         else
         {
            Print("Position fermée avec succès. Ticket: ", ticket);
         }
      }
   }
}