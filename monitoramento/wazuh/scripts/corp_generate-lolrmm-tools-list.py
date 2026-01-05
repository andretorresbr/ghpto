#!/usr/bin/env python3
# corp_generate-lolrmm-tools-list.py
# Baseado no projeto https://lolrmm.io/
# Arquivo baixado e analizado pelos script: https://lolrmm.io/api/rmm_tools.csv

import csv
import os
import sys
import urllib.request
import re

CSV_URL = "https://lolrmm.io/api/rmm_tools.csv"
OUTPUT_FILE = "/var/ossec/etc/lists/rmm_tools"


def download_csv(url):
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.read().decode("utf-8", errors="ignore")
    except Exception as e:
        print(f"[ERRO] Falha ao baixar CSV: {e}")
        sys.exit(1)


def extract_exes(text):
    """
    Extrai arquivos .exe, remove wildcards,
    normaliza para lowercase e retorna set().
    """
    exes = set()
    if not text:
        return exes

    matches = re.findall(r"[A-Za-z0-9_\-*]+\.exe", text, re.IGNORECASE)
    for m in matches:
        exe = m.replace("*", "").lower()
        if exe.endswith(".exe"):
            exes.add(exe)

    return exes


def generate_list(csv_content):
    output_lines = []

    reader = csv.DictReader(csv_content.splitlines())
    for row in reader:
        name = row.get("Name", "").strip()
        if not name:
            continue

        exes = set()
        exes |= extract_exes(row.get("Filename", ""))
        exes |= extract_exes(row.get("InstallationPaths", ""))

        for exe in sorted(exes):
            output_lines.append(f'{exe}:"{name}"')

    return output_lines


def write_output(lines, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)

    try:
        with open(path, "w") as f:
            for line in lines:
                f.write(line + "\n")
    except Exception as e:
        print(f"[ERRO] Falha ao escrever arquivo: {e}")
        sys.exit(1)


def main():
    print("[INFO] Baixando LOLRMM CSV...")
    csv_content = download_csv(CSV_URL)

    print("[INFO] Extraindo executáveis .exe (lowercase)...")
    lines = generate_list(csv_content)

    if not lines:
        print("[ERRO] Nenhuma entrada gerada.")
        sys.exit(1)

    print(f"[INFO] Gravando {len(lines)} linhas em {OUTPUT_FILE}")
    write_output(lines, OUTPUT_FILE)

    print("[OK] Lista RMM gerada com sucesso.")


if __name__ == "__main__":
    main()
