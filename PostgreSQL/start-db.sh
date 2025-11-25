#!/bin/bash

if [ -z "$VAULT_ADDR" ]; then
    echo "[ERRO] A variável VAULT_ADDR não está definida."
    echo "Execute 'source ~/.bashrc' ou exporte a variável manualmente."
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo "[ERRO] A variável VAULT_TOKEN não está definida."
    echo "Verifique se você exportou o token corretamente."
    exit 1
fi

SECRET_URL="${VAULT_ADDR}/v1/database/postgres/data/v1"

echo "[DB] Verificando dependências..."
if ! command -v jq &> /dev/null; then
    echo "[ERRO] 'jq' não instalado. Instale com: sudo apt install jq"
    exit 1
fi

echo "[DB] Conectando ao Vault em: $VAULT_ADDR"

JSON_RESULT=$(curl -s --header "X-Vault-Token: ${VAULT_TOKEN}" "${SECRET_URL}")

if [ -z "$JSON_RESULT" ]; then
    echo "[ERRO] O Vault não retornou nada. Verifique se o Vault está rodando."
    exit 1
fi

DB_USER=$(echo $JSON_RESULT | jq -r ".data.data.username")
DB_PASS=$(echo $JSON_RESULT | jq -r ".data.data.password")

if [ "$DB_USER" == "null" ] || [ -z "$DB_USER" ]; then
    echo "[ERRO] Falha ao ler o segredo!"
    echo "Resposta recebida do Vault:"
    echo "$JSON_RESULT" | jq .
    exit 1
fi

echo "[DB] Credenciais obtidas com sucesso para: $DB_USER"

echo "[DB] Gerando arquivo .env temporário..."
cat > .env << EOL
# Gerado automaticamente via Vault Environment Variables
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_DB=homelab
EOL

echo "[DB] Subindo o container..."
docker compose up -d

echo "--- Sucesso! Banco de Dados Iniciado ---"