enum TipoRelativo {
   MAXIMO,
   MINIMO,
   NONE,
};

struct Relativo {
   double price;
   datetime time;
   TipoRelativo tipo;
};

class ColaRelativos {
   public:
      Relativo relativos[];
      void add(Relativo &relativo);
      Relativo pop();
      void reset();
      
      // TODO:
      vector toNNVector(int size, MqlRates &_velas[]); 
};

void ColaRelativos::add(Relativo &relativo) {
   int num_relativos = ArraySize(this.relativos);
   
   ArrayResize(this.relativos, num_relativos+1);
   
   this.relativos[num_relativos] = relativo;
}

Relativo ColaRelativos::pop() {
   Relativo result = this.relativos[0];
   int num_relativos = ArraySize(this.relativos);
   
   for (int i = 1; i < num_relativos; i++) {
      this.relativos[i-1] = this.relativos[i];
   }
   
   return result;
}


vector ColaRelativos::toNNVector(int size, MqlRates &_velas[]) {
   vector result(size*2);
   
   if (ArraySize(this.relativos) < size) return result;
   
   for (int i = -1; i < size-1; i++) {
      double diff_precio = 0;
      long diff_time = 0;
      if (i == -1) {
         diff_precio = _velas[0].close-this.relativos[0].price;
         diff_time = _velas[0].time-this.relativos[0].time;
      } else {
         diff_precio = this.relativos[i].price-this.relativos[i+1].price;
         diff_time = this.relativos[i].time-this.relativos[i+1].time;
      }
      result.Set((i+1)*2, diff_precio);
      result.Set(((i+1)*2)+1, diff_time);
   }
   return result;
}


TipoRelativo es_relativo(MqlRates &_velas[], int indice, int profundidad) {
   bool es_maximo = true;
   bool es_minimo = true;
   
   for (int i = indice-profundidad; i < indice+profundidad-1; i++) {
      if (i == indice) continue;
   
      if (_velas[i].close < _velas[indice].close) es_minimo = false;
      if (_velas[i].close > _velas[indice].close) es_maximo = false;
      
      if (!es_maximo && !es_minimo) break;
   }
   
   if (es_maximo) return MAXIMO;
   if (es_minimo) return MINIMO;
   
   return NONE;
}

void ColaRelativos::reset() {
   ArrayResize(this.relativos, 0);
}


void buscar_relativos(MqlRates &_velas[], int profundidad, ColaRelativos &_cola) {
   int num_velas = ArraySize(_velas);
   for (int i = profundidad; i < num_velas-profundidad; i++) {
      TipoRelativo tipo = es_relativo(_velas, i, profundidad);
      
      if (tipo != NONE) {
         Relativo relativo;
         relativo.price = _velas[i].close;
         relativo.time = _velas[i].time;
         if (tipo == MAXIMO) relativo.tipo = MAXIMO;
         else relativo.tipo = MINIMO;
         
         _cola.add(relativo);
      
         /*
         string name = IntegerToString(i)+"-Punto";
         ObjectCreate(
            0,
            name,
            tipo == MAXIMO ? OBJ_ARROW_DOWN : OBJ_ARROW_UP,
            0,
            relativo.time,
            relativo.price+(tipo == MAXIMO ? 2000*_Point : 0)
         );
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 5);
         */
      }
   }
}

void dibujar_lineas(ColaRelativos &_cola, MqlRates &_velas[]) {
   int num_relativos = ArraySize(_cola.relativos);
   for (int i = 0; i < num_relativos-1; i++) {
      string name = IntegerToString(i)+"-"+IntegerToString(i+1)+"-Linea";
      ObjectCreate(
         0,
         name,
         OBJ_TREND,
         0,
         _cola.relativos[i].time,
         _cola.relativos[i].price,
         _cola.relativos[i+1].time,
         _cola.relativos[i+1].price
      );
      double diff = _cola.relativos[i].price-_cola.relativos[i+1].price;
      ObjectSetInteger(0, name, OBJPROP_COLOR, diff > 0 ? clrGreen : clrRed);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 5);
   }
   string name = "Linea-precio";
   double diff_precio = _velas[0].close-_cola.relativos[0].price;
   ObjectCreate(
      0,
      name,
      OBJ_TREND,
      0,
      _cola.relativos[0].time,
      _cola.relativos[0].price,
      _velas[0].time,
      _velas[0].close
   );
   ObjectSetInteger(0, name, OBJPROP_COLOR, diff_precio > 0 ? clrGreen : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 5);
}