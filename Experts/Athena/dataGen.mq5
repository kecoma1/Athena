#include <Athena/Relative.mqh>
ColaRelativos _cola_compra;
ColaRelativos _cola_venta;

#include <Trade/Trade.mqh>
CTrade trade;
ulong ticket_compra;
ulong ticket_venta;

input string filename_compra = "datos_compra.csv";
input string filename_venta = "datos_venta.csv";
input int SL_POINTS = 6000;
input int TP_POINTS = 6000;
input int HORA_ENTRADA = 1;
input int HORA_SALIDA = 9;
input int RELATIVOS_A_CONTAR = 5;

int fh_compra;
int fh_venta;

double range_max = 0;
double range_min = INT_MAX;

            // MENCIONAR
double precio_compra = 0;
double precio_venta = 0;
datetime tiempo_compra=0;
datetime tiempo_venta=0;

MqlRates velas[];


int dia = 0;
bool cambio_dia() {
   MqlDateTime time;
   TimeCurrent(time);
   
   if (dia != time.day) {
      dia = time.day;
      return true;
   }
   
   return false;
}

bool cruce_rango_max() {
   return velas[0].close >= range_max && range_max != 0;
}

bool cruce_rango_min() {
   return velas[0].close <= range_min && range_min != INT_MAX;
}

bool en_horario() {
   MqlDateTime time;
   TimeCurrent(time);
   
   return time.hour >= HORA_ENTRADA && time.hour < HORA_SALIDA;
}

bool compra_cerrada() {
   return !PositionSelectByTicket(ticket_compra);
}

bool venta_cerrada() {
   return !PositionSelectByTicket(ticket_venta);
}


void OnInit() {
   fh_compra = FileOpen(filename_compra, FILE_WRITE, 0);
   string cabecera_compra = "AB,TAB,BC,TBC,CD,TCD,DE,TDE,EF,TEF,COMPRA";   
   FileWrite(fh_compra, cabecera_compra);
   
   fh_venta = FileOpen(filename_venta, FILE_WRITE, 0);
   string cabecera_venta = "AB,TAB,BC,TBC,CD,TCD,DE,TDE,EF,TEF,VENTA";   
   FileWrite(fh_venta, cabecera_venta);
   
   ArraySetAsSeries(velas, true);
}

void OnDeinit(const int reason) {
   FileClose(fh_compra);
   FileClose(fh_venta);
}

void OnTick() {
   CopyRates(_Symbol, _Period, 0, 2000, velas);

   if (cambio_dia()) {
      range_max = 0;
      range_min = INT_MAX;
   }

   if (en_horario()) {
      // Recoger máximo y mínimo
      if (range_max < velas[0].high) range_max = velas[0].high;
      if (range_min > velas[0].low) range_min = velas[0].low;
   } else {
      if (cruce_rango_max() && compra_cerrada()) {
         buscar_relativos(velas, 10, _cola_compra);
         dibujar_lineas(_cola_compra, velas);
         trade.Buy(0.1, _Symbol, 0, range_max-SL_POINTS*_Point, range_max+TP_POINTS*_Point);
            // MENCIONAR
         precio_compra = range_max;
         tiempo_compra = velas[0].time;
         range_max = 0;
         ticket_compra = trade.ResultOrder();
      }
      if (cruce_rango_min() && venta_cerrada()) {
         buscar_relativos(velas, 10, _cola_venta);
         dibujar_lineas(_cola_venta, velas);
         trade.Sell(0.1, _Symbol, 0, range_min+SL_POINTS*_Point, range_min-TP_POINTS*_Point);
            // MENCIONAR
         precio_venta = range_max;
         tiempo_venta = velas[0].time;
         range_min = INT_MAX;
         ticket_venta = trade.ResultOrder();
      }
   }
}

            // MENCIONAR
string recoger_datos(ColaRelativos &cola, bool isBuy) {
   string dato = "";
   for (int i = -1; i < RELATIVOS_A_CONTAR-1; i++) {
      double diff_precio = 0;
      long diff_time = 0;
      if (i == -1) {
         diff_precio = (isBuy ? precio_compra : precio_venta)-cola.relativos[0].price;
         diff_time = (isBuy ? tiempo_compra : tiempo_venta)-cola.relativos[0].time;
      } else {
         diff_precio = cola.relativos[i].price-cola.relativos[i+1].price;
         diff_time = cola.relativos[i].time-cola.relativos[i+1].time;
      }
      dato += DoubleToString(diff_precio)+","+IntegerToString(diff_time)+",";
   }
   
   return dato;
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   HistoryDealSelect(trans.deal);
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if (entry == DEAL_ENTRY_OUT) {
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
         if (trans.deal_type == DEAL_TYPE_BUY) {
            // MENCIONAR
            if (ArraySize(_cola_venta.relativos) > RELATIVOS_A_CONTAR*2) {
               string dato = recoger_datos(_cola_venta, false);
               if (profit < 0) dato += "0";
               else dato += "1";
               FileWrite(fh_venta, dato);
               _cola_venta.reset();
            }
         } else if (trans.deal_type == DEAL_TYPE_SELL) {
            // MENCIONAR
            if (ArraySize(_cola_compra.relativos) > RELATIVOS_A_CONTAR*2) {
               string dato = recoger_datos(_cola_compra, true);
               if (profit < 0) dato += "0";
               else dato += "1";
               FileWrite(fh_compra, dato);
               _cola_compra.reset();
            }
         }
      }
   }
}