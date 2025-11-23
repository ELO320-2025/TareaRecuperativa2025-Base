#!/bin/bash

# 1. CONFIGURACIÓN
EJECUTABLE="./sertel"
echo "--- Iniciando Test para SERTEL ---"

# Verificar existencia del ejecutable
if [ ! -f "$EJECUTABLE" ]; then
    echo "ERROR: El ejecutable '$EJECUTABLE' no fue encontrado."
    echo "Asegúrate de haber compilado el proyecto (make) y de que el ejecutable se llame 'sertel'."
    exit 1
fi

# 2. LIMPIEZA INICIAL (Asegurar que los archivos de resultados estén limpios)
echo "Limpiando archivos de resultados previos..."
> votos_por_mesa.txt # Vacía el archivo de persistencia

# 3. DATOS DE ENTRADA SIMULADOS
# Secuencia de comandos que simulan la interacción del usuario:
# 2\n18.000.000-1\n    -> Consultar datos de Alonso Díaz
# 1\n25.000.000-2\n    -> Intento de justificación fallido (RUT no existe)
# 1\n18.000.000-1\n    -> Justificación de Alonso Díaz
# 3\nEscuela Central\n1\n -> Ingreso de resultados por Mesa 1
# 45\n30\n             -> Votos Presidente
# 40\n35\n             -> Votos Senador
# 48\n27\n             -> Votos Diputado
# 4\nL\nEscuela Central\n -> Recuento Parcial por Local "Escuela Central"
# 5\n                 -> Intento de Generar Lista Final (Debe fallar)
# 0\n                 -> Salir
INPUT_SEQUENCE=$(cat <<EOF
2
18.000.000-1
1
25.000.000-2
1
18.000.000-1
3
Escuela Central
1
45
30
40
35
48
27
4
L
Escuela Central
5
0
EOF
)

# 4. EJECUCIÓN Y CAPTURA DE SALIDA
echo -e "\n--- Ejecutando $EJECUTABLE con argumentos de entrada ---\n"
# Se asume que el programa recibe los archivos de entrada como parámetros.
OUTPUT=$($EJECUTABLE ./data/registro_electoral.txt ./data/candidatos.txt ./data/geografia_electoral.txt <<< "$INPUT_SEQUENCE")

# Imprimir la salida completa para revisión manual
echo "$OUTPUT"

# 5. VERIFICACIÓN DE PUNTOS CLAVE

echo -e "\n--- Verificación de Resultados ---"

# A. Verificación de Justificación (Lógica de validación de RUT)
if echo "$OUTPUT" | grep -q "ERROR: El RUT 25.000.000-2 no se encuentra en el Registro Electoral."; then
    echo "[Punto A] Validación de RUT para Justificación: OK."
else
    echo "[Punto A] Falla la validación de RUT."
fi

# B. Verificación de Ingreso de Votos y Estado de Votación
# Se verifica que el mensaje de éxito y la marca de voto se hayan aplicado.
if echo "$OUTPUT" | grep -q "Resultados de Mesa 1 (Escuela Central) ingresados y totalizados." && \
   echo "$OUTPUT" | grep -q "Voto de Elena Flores (RUT 19.000.000-K) marcado como 'Sí'."; then
    echo "[Punto B] Ingreso de Votos y Actualización del Estado: OK."
else
    echo "[Punto B] Falla en el ingreso de votos o en la actualización del estado de votación."
fi

# C. Verificación de Recuento Parcial (Local)
# Se verifica un valor clave del recuento (ej. los 48 votos de Ruiz)
if echo "$OUTPUT" | grep -E -q "Carlos Ruiz.*48 votos"; then
    echo "[Punto C] Recuento Parcial por Local: OK (Votos de Carlos Ruiz: 48)."
else
    echo "[Punto C] Falla en el recuento parcial o en la visualización de datos."
fi

# D. Verificación de Falla en Generación de Electos
# Se verifica que la funcionalidad de estadística parcial (Error al 100%) funcione.
if echo "$OUTPUT" | grep -q "ERROR: No se puede generar la lista final. Se requiere que el 100% de las mesas ingresen sus resultados."; then
    echo "[Punto D] Falla en Generación de Electos por Recuento Incompleto: OK."
else
    echo "[Punto D] No se detecta el error por recuento incompleto."
fi

# E. Verificación de Persistencia (Votos por mesa)
# Se verifica que el archivo de persistencia NO esté vacío.
if [ -s "votos_por_mesa.txt" ]; then
    echo "[Punto E] Persistencia de Votos: OK (Archivo votos_por_mesa.txt no está vacío)."
else
    echo "[Punto E] Falla la persistencia. El archivo votos_por_mesa.txt está vacío."
fi

echo -e "\n--- Test Finalizado ---"