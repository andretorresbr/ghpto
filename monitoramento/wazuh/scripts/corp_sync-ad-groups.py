#!/usr/bin/env python3

# Pre-requisito:
#  apt install python3-ldap3 python3-dotenv
#  chown wazuh:root /opt/scripts/.env /opt/scripts/corp_sync-ad-groups.py
#  chmod 600 /opt/scripts/.env /opt/scripts/corp_sync-ad-groups.py

from ldap3 import SIMPLE, Server, Connection, ALL, SUBTREE
from pathlib import Path
from dotenv import load_dotenv
import os

# =============================
# CARREGA VARIÁVEIS DE AMBIENTE
# =============================

ENV_PATH = "/opt/scripts/.env"
load_dotenv(ENV_PATH)

BIND_PASSWORD = os.getenv("WAZUH_BIND_PASSWORD")

if not BIND_PASSWORD:
    raise RuntimeError("Variável WAZUH_BIND_PASSWORD não encontrada no arquivo .env")

# =============================
# CONFIGURAÇÕES DO AD
# =============================

AD_SERVER = "corp-dc.corp.local"
AD_DOMAIN = "corp.local"
AD_BASE_DN = "DC=corp,DC=local"

BIND_USER = "svc_wazuh_bind"

# =============================
# MAPEAMENTO GRUPO AD -> ARQUIVO
# =============================
#
# group_name : {
#     "object_class": "user" | "computer",
#     "output": Path("/caminho/arquivo")
# }

GROUP_FILE_MAP = {
    "T0 Users": {
        "object_class": "user",
        "output": Path("/var/ossec/etc/lists/t0_users")
    },
    "T0 Servers": {
        "object_class": "computer",
        "output": Path("/var/ossec/etc/lists/t0_servers")
    },
    "Domain Controllers": {
        "object_class": "computer",
        "output": Path("/var/ossec/etc/lists/domain_controllers")
    }
}

# =============================
# FUNÇÕES
# =============================

def connect_ldap():
    server = Server(
        AD_SERVER,
        get_info=ALL,
        connect_timeout=10
    )

    conn = Connection(
        server,
        user=f"{BIND_USER}@{AD_DOMAIN}",
        password=BIND_PASSWORD,
        authentication=SIMPLE,
        auto_bind=True
    )
    return conn


def get_group_members(conn, group_name, object_class):
    results = []

    # Tratamento especial para Domain Controllers
    if group_name.lower() == "domain controllers" and object_class == "computer":
        search_filter = "(&(objectClass=computer)(primaryGroupID=516))"

        conn.search(
            search_base=AD_BASE_DN,
            search_filter=search_filter,
            search_scope=SUBTREE,
            attributes=["sAMAccountName"]
        )

        for entry in conn.entries:
            name = entry["sAMAccountName"].value
            if not name.endswith("$"):
                name += "$"
            results.append(name)

        return sorted(set(results))

    # Fluxo normal para outros grupos
    search_filter = f"(&(objectClass=group)(cn={group_name}))"

    conn.search(
        search_base=AD_BASE_DN,
        search_filter=search_filter,
        attributes=["member"]
    )

    if not conn.entries:
        return []

    members_dns = conn.entries[0]["member"].values

    for member_dn in members_dns:
        conn.search(
            search_base=member_dn,
            search_filter=f"(objectClass={object_class})",
            search_scope=SUBTREE,
            attributes=["sAMAccountName"]
        )

        if conn.entries:
            name = conn.entries[0]["sAMAccountName"].value
            if object_class == "computer" and not name.endswith("$"):
                name += "$"
            results.append(name)

    return sorted(set(results))

def write_cdb_list(path, entries):
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="utf-8") as f:
        for entry in entries:
            # Sempre grava o formato original
            f.write(f"{entry}:alert\n")

            # Se for computador (termina com $), grava também o FQDN
            if entry.endswith("$"):
                hostname = entry.rstrip("$")
                fqdn = f"{hostname}.{AD_DOMAIN}"
                f.write(f"{fqdn}:alert\n")

# =============================
# MAIN
# =============================

def main():
    conn = connect_ldap()

    for group_name, config in GROUP_FILE_MAP.items():
        object_class = config["object_class"]
        output_file = config["output"]

        entries = get_group_members(conn, group_name, object_class)
        write_cdb_list(output_file, entries)

        print(f"[OK] {len(entries)} entradas do grupo '{group_name}' gravadas em {output_file}")

    conn.unbind()


if __name__ == "__main__":
    main()

