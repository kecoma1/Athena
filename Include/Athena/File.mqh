
int numero_lineas_csv(string filename) {
   int lineas = 0;
   int fh = FileOpen(filename, FILE_ANSI|FILE_COMMON|FILE_CSV|FILE_READ, "\n");
   
   while(!FileIsEnding(fh)) {
      FileReadString(fh);
      lineas++;
   }
   
   FileClose(fh);
   
   return lineas;
}

int numero_columnas_csv(string filename) {
   int fh = FileOpen(filename, FILE_ANSI|FILE_COMMON|FILE_CSV|FILE_READ, "\n");
   
   string linea = FileReadString(fh);
   
   string columnas[];
   StringSplit(linea, ',', columnas);
   
   FileClose(fh);
   
   return ArraySize(columnas);
}

matrix cargar_atributos_csv(string filename) {
   int num_columnas = numero_columnas_csv(filename);
   int num_lineas = numero_lineas_csv(filename);
   
   matrix atributos(num_lineas-1, num_columnas-1);
   
   int fh = FileOpen(filename, FILE_ANSI|FILE_COMMON|FILE_CSV|FILE_READ, "\n");
   
   FileReadString(fh);
   
   int index = 0;
   while(!FileIsEnding(fh)) {
      vector atributos_linea(num_columnas-1);
      
      string linea = FileReadString(fh);
      
      string datos[];
      StringSplit(linea, ',', datos);
      
      for (int i = 0; i < num_columnas; i++) {
         if (i != num_columnas-1) atributos_linea.Set(i, StringToDouble(datos[i]));
      }
      
      atributos.Row(atributos_linea, index);
      index++;
   }
   FileClose(fh);
   
   return atributos;
}

matrix cargar_clases_csv(string filename) {
   int num_columnas = numero_columnas_csv(filename);
   int num_lineas = numero_lineas_csv(filename);
   
   matrix clases(num_lineas-1, 1);
   
   int fh = FileOpen(filename, FILE_ANSI|FILE_COMMON|FILE_CSV|FILE_READ, "\n");
   
   FileReadString(fh);
   
   int index = 0;
   while(!FileIsEnding(fh)) {
      vector clases_linea(1);
      
      string linea = FileReadString(fh);
      
      string datos[];
      StringSplit(linea, ',', datos);
      
      clases_linea.Set(0, StringToDouble(datos[num_columnas-1]));
      
      clases.Row(clases_linea, index);
      index++;
   }
   FileClose(fh);
   
   return clases;
}