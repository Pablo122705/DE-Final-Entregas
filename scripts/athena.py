#!/usr/bin/env python3
"""Ejecuta un archivo .sql en Athena (workgroup del ejercicio), descarga el resultado
y registra la ejecución en evidencias/ejecuciones_athena.csv.

Uso (desde la raíz del repositorio):
    python3 scripts/athena.py <etapa> <archivo_sql> <resultado.csv> [<resultado2.csv> ...]

Si el archivo SQL tiene varias sentencias separadas por ';', se ejecuta cada una por
separado (Athena ejecuta una sentencia por ejecución) y se necesita un CSV por sentencia.
Solo usa la biblioteca estándar de Python y la AWS CLI v2.
"""
import csv
import io
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
REGISTRO = RAIZ / "evidencias" / "ejecuciones_athena.csv"
COLUMNAS = ["etapa", "archivo_sql", "id_ejecucion", "archivo_resultado"]


def aws(*args):
    salida = subprocess.run(["aws", *args, "--output", "json"], check=True,
                            capture_output=True, text=True)
    return json.loads(salida.stdout) if salida.stdout.strip() else {}


def sentencias(texto):
    sin_comentarios = "\n".join(l for l in texto.splitlines() if not l.strip().startswith("--"))
    return [s.strip() for s in sin_comentarios.split(";") if s.strip()]


def registrar(fila):
    filas = []
    if REGISTRO.exists():
        with REGISTRO.open(newline="", encoding="utf-8") as f:
            filas = list(csv.DictReader(f))
    # Si se repite la misma consulta/etapa/resultado, se reemplaza la fila anterior
    filas = [f for f in filas if not (f["etapa"] == fila["etapa"]
                                      and f["archivo_resultado"] == fila["archivo_resultado"])]
    filas.append(fila)
    with REGISTRO.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNAS, lineterminator="\n")
        w.writeheader()
        w.writerows(filas)


def main():
    if len(sys.argv) < 4 or sys.argv[1] not in ("inicial", "final"):
        sys.exit(__doc__)
    etapa, archivo_sql, resultados = sys.argv[1], sys.argv[2], sys.argv[3:]
    salidas = json.loads((RAIZ / "evidencias" / "outputs.json").read_text())
    region = salidas["region"]["value"]
    workgroup = salidas["workgroup"]["value"]
    base = salidas["base_datos"]["value"]

    consultas = sentencias((RAIZ / archivo_sql).read_text(encoding="utf-8"))
    if len(consultas) != len(resultados):
        sys.exit(f"{archivo_sql} tiene {len(consultas)} sentencias y se dieron {len(resultados)} CSV")

    for consulta, resultado in zip(consultas, resultados):
        id_ejec = aws("athena", "start-query-execution", "--region", region,
                      "--work-group", workgroup,
                      "--query-execution-context", f"Database={base}",
                      "--query-string", consulta)["QueryExecutionId"]
        print(f"\n[{etapa}] {archivo_sql} -> {resultado}\n  id_ejecucion: {id_ejec}", flush=True)
        while True:
            info = aws("athena", "get-query-execution", "--region", region,
                       "--query-execution-id", id_ejec)["QueryExecution"]
            estado = info["Status"]["State"]
            if estado in ("SUCCEEDED", "FAILED", "CANCELLED"):
                break
            time.sleep(1)
        if estado != "SUCCEEDED":
            sys.exit(f"  ERROR {estado}: {info['Status'].get('StateChangeReason', '')}")

        ubicacion = info["ResultConfiguration"]["OutputLocation"]
        with tempfile.TemporaryDirectory() as tmp:
            local = Path(tmp) / "r.csv"
            subprocess.run(["aws", "s3", "cp", ubicacion, str(local), "--region", region,
                            "--only-show-errors"], check=True)
            filas = list(csv.reader(io.StringIO(local.read_text(encoding="utf-8"))))
        destino = RAIZ / resultado
        destino.parent.mkdir(parents=True, exist_ok=True)
        # Se reescribe sin comillas, separador coma y finales LF (igual que las referencias)
        with destino.open("w", newline="", encoding="utf-8") as f:
            csv.writer(f, lineterminator="\n").writerows(filas)
        print(f"  resultado en S3: {ubicacion}")
        print("  " + destino.read_text(encoding="utf-8").replace("\n", "\n  "))
        registrar({"etapa": etapa, "archivo_sql": archivo_sql,
                   "id_ejecucion": id_ejec, "archivo_resultado": resultado})


if __name__ == "__main__":
    main()
