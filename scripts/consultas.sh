#!/usr/bin/env bash
# Ejecuta las consultas de una etapa (inicial | final) y compara con resultados_esperados/.
# No sube archivos a S3: la carga de cada día se hace a mano con aws s3 cp (ver README).
set -euo pipefail
cd "$(dirname "$0")/.."
etapa="${1:?Uso: bash scripts/consultas.sh inicial|final}"

if [ "$etapa" = inicial ]; then
    python3 scripts/athena.py inicial consultas/conteo_registros.sql resultados/inicial/conteo_registros.csv
    python3 scripts/athena.py inicial consultas/intentos_por_fecha_estado.sql resultados/inicial/intentos_por_fecha_estado.csv
    python3 scripts/athena.py inicial consultas/porcentaje_exito_por_fecha_ciudad.sql resultados/inicial/porcentaje_exito_por_fecha_ciudad.csv
    python3 scripts/athena.py inicial consultas/duracion_promedio_2026-10-02.sql resultados/inicial/duracion_promedio_2026-10-02.csv
    pares=(
        "resultados/inicial/intentos_por_fecha_estado.csv resultados_esperados/intentos_por_fecha_estado_inicial.csv"
        "resultados/inicial/porcentaje_exito_por_fecha_ciudad.csv resultados_esperados/porcentaje_exito_por_fecha_ciudad_inicial.csv"
        "resultados/inicial/duracion_promedio_2026-10-02.csv resultados_esperados/duracion_promedio_2026-10-02.csv"
    )
elif [ "$etapa" = final ]; then
    python3 scripts/athena.py final consultas/verificacion_tercer_dia.sql \
        resultados/final/verificacion_tercer_dia.csv \
        resultados/final/verificacion_tercer_dia_conteo_estado.csv \
        resultados/final/verificacion_total_registros.csv
    python3 scripts/athena.py final consultas/intentos_por_fecha_estado.sql resultados/final/intentos_por_fecha_estado.csv
    python3 scripts/athena.py final consultas/porcentaje_exito_por_fecha_ciudad.sql resultados/final/porcentaje_exito_por_fecha_ciudad.csv
    python3 scripts/athena.py final consultas/duracion_promedio_2026-10-02.sql resultados/final/duracion_promedio_2026-10-02.csv
    pares=(
        "resultados/final/intentos_por_fecha_estado.csv resultados_esperados/intentos_por_fecha_estado_final.csv"
        "resultados/final/porcentaje_exito_por_fecha_ciudad.csv resultados_esperados/porcentaje_exito_por_fecha_ciudad_final.csv"
        "resultados/final/duracion_promedio_2026-10-02.csv resultados_esperados/duracion_promedio_2026-10-02.csv"
    )
else
    echo "Etapa desconocida: $etapa" >&2; exit 1
fi

reporte="evidencias/comparacion_${etapa}.txt"
{
    echo "Comparación de resultados de Athena con resultados_esperados/ - etapa $etapa"
    echo "Fecha: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for par in "${pares[@]}"; do
        set -- $par
        if diff -u "$2" "$1"; then echo "IGUAL      $1 == $2"; else echo "DIFERENTE  $1 != $2"; fi
    done
} | tee "$reporte"
echo; echo "Registro de ejecuciones:"; cat evidencias/ejecuciones_athena.csv
