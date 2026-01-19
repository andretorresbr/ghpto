#!/usr/bin/env python3

import os
import sys

TASKS = [
    {
        "source_dir": "/var/ossec/ruleset/rules",
        "output_file": "all_default_rules.xml",
        "description": "Default Wazuh rules"
    },
    {
        "source_dir": "/var/ossec/etc/rules",
        "output_file": "all_custom_rules.xml",
        "description": "Custom Wazuh rules"
    },
    {
        "source_dir": "/var/ossec/ruleset/decoders",
        "output_file": "all_default_decoders.xml",
        "description": "Default Wazuh decoders"
    },
    {
        "source_dir": "/var/ossec/etc/decoders",
        "output_file": "all_custom_decoders.xml",
        "description": "Custom Wazuh decoders"
    }
]


def concat_xml_files(source_dir, output_file, description):
    print(f"\n[*] Processando {description}")
    print(f"    Diretório origem : {source_dir}")
    print(f"    Arquivo destino  : {output_file}")

    if not os.path.isdir(source_dir):
        print(f"    [ERRO] Diretório não existe. Pulando.")
        return

    xml_files = sorted(
        f for f in os.listdir(source_dir)
        if f.endswith(".xml") and os.path.isfile(os.path.join(source_dir, f))
    )

    if not xml_files:
        print(f"    [AVISO] Nenhum arquivo XML encontrado.")
        return

    print(f"    Arquivos encontrados: {len(xml_files)}")

    with open(output_file, "w", encoding="utf-8") as outfile:
        for xml_file in xml_files:
            file_path = os.path.join(source_dir, xml_file)
            print(f"      - Adicionando {xml_file}")

            with open(file_path, "r", encoding="utf-8") as infile:
                outfile.write(infile.read())
                outfile.write("\n")

    print(f"    [OK] Arquivo criado com sucesso.")


def main():
    print("=== Wazuh XML Concatenator ===")

    for task in TASKS:
        concat_xml_files(
            task["source_dir"],
            task["output_file"],
            task["description"]
        )

    print("\n=== Processo finalizado ===")


if __name__ == "__main__":
    if os.geteuid() != 0:
        print("[ERRO] Este script deve ser executado como root.")
        sys.exit(1)

    main()
