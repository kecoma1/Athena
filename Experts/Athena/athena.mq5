#include <Athena/Relative.mqh>
#include <Athena/File.mqh>
#include <Trade/Trade.mqh>
#include <NN.mqh>

CTrade trade;

input int SL_POINTS = 2000;
input int TP_POINTS = 6000;
input int HORA_ENTRADA = 1;
input int HORA_SALIDA = 9;
input int RELATIVOS_A_CONTAR = 5;
input double UMBRAL = 0.9;


MqlRates velas[];
ColaRelativos _cola_compra;
ColaRelativos _cola_venta;

double range_max = 0;
double range_min = INT_MAX;


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

double sigmoide(double v) {
   return 1/(1+MathPow(2.71828, v*-1));
}

double derivada_sigmoide(double v) {
   return sigmoide(v)*(1-sigmoide(v));
}

int estructura[4] = {10, 64, 64, 1};

RedNeuronal rn_compra(4, estructura, sigmoide, derivada_sigmoide, 1);
RedNeuronal rn_venta(4, estructura, sigmoide, derivada_sigmoide, 1);

void OnInit() {
   ArraySetAsSeries(velas, true);
   
   matrix atributos_compra = cargar_atributos_csv("datos_compra_us100_short.csv");
   matrix clases_compra = cargar_clases_csv("datos_compra_us100_short.csv");
   Print("-------- Entrenando la red neuronal de compra -------- ");
   rn_compra.entrenar(1500, atributos_compra, clases_compra);
   
   int aciertos_compra = 0;
   for (ulong i = 0; i < atributos_compra.Rows(); i++) {
      vector resultado = rn_compra.predecir(atributos_compra.Row(i));
      if ((resultado[0] > UMBRAL ? 1 : 0) == clases_compra.Row(i)[0]) aciertos_compra++;
   }
   
   matrix atributos_venta = cargar_atributos_csv("datos_venta_us100_short.csv");
   matrix clases_venta = cargar_clases_csv("datos_venta_us100_short.csv");
   Print("-------- Entrenando la red neuronal de venta -------- ");
   rn_venta.entrenar(1500, atributos_venta, clases_venta);
   int aciertos_venta = 0;
   for (ulong i = 0; i < atributos_venta.Rows(); i++) {
      vector resultado = rn_venta.predecir(atributos_venta.Row(i));
      if ((resultado[0] > UMBRAL ? 1 : 0) == clases_venta.Row(i)[0]) aciertos_venta++;
   }
   Print("Aciertos compra: ", IntegerToString(aciertos_compra), "/", IntegerToString(atributos_compra.Rows()));
   Print("Aciertos venta: ", IntegerToString(aciertos_venta), "/", IntegerToString(atributos_venta.Rows()));
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
      if (cruce_rango_max()) {
         
         buscar_relativos(velas, 10, _cola_compra);
         dibujar_lineas(_cola_compra, velas);
         vector atributos = _cola_compra.toNNVector(RELATIVOS_A_CONTAR, velas);
         _cola_compra.reset();
         vector resultado = rn_compra.predecir(atributos);
         Print("Predicción RN compra: ", DoubleToString(resultado[0]));
         
         if (resultado[0] > UMBRAL) trade.Buy(1, _Symbol, 0, range_max-SL_POINTS*_Point, range_max+TP_POINTS*_Point);
         
         
         range_max = 0;
      }
      if (cruce_rango_min()) {
         buscar_relativos(velas, 10, _cola_venta);
         dibujar_lineas(_cola_venta, velas);
         vector atributos = _cola_venta.toNNVector(RELATIVOS_A_CONTAR, velas);
         _cola_venta.reset();
         vector resultado = rn_venta.predecir(atributos);
         Print("Predicción RN venta: ", DoubleToString(resultado[0]));
         
         if (resultado[0] > UMBRAL) trade.Sell(1, _Symbol, 0, range_min+SL_POINTS*_Point, range_min-TP_POINTS*_Point);
         
         range_min = INT_MAX;
      }
   }
}