#!/bin/bash

VAULT_PATH="$1"
HOST_GIT_DIR=$HOST_GIT_DIR
HOST_BACKUP_DIR=$VAULT_NAS_DIR

if [ -z "$VAULT_PATH" ]; then
    echo "❌ Uso: ./vault-start.sh <CAMINHO_DO_SEGREDO>"
    echo "Exemplo: ./vault-start.sh jeanverso/data/jenkins"
    exit 1
fi

if [ -z "$HOST_GIT_DIR" ]; then
    echo "❌ ERRO: A variável de ambiente HOST_GIT_DIR não está definida."
    exit 1
fi

if [ -z "$HOST_BACKUP_DIR" ]; then
    echo "❌ ERRO: A variável de ambiente VAULT_NAS_DIR não está definida."
    exit 1
fi

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=$VAULT_TOKEN}"

if ! command -v jq &> /dev/null; then
    echo "❌ ERRO: 'jq' não instalado."
    exit 1
fi

echo "🔐 [VAULT] Buscando segredos em: $VAULT_PATH"

JSON_RESPONSE=$(curl -s --header "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/${VAULT_PATH}")

if echo "$JSON_RESPONSE" | grep -q "errors"; then
    echo "❌ ERRO no Vault: $(echo $JSON_RESPONSE | jq -r '.errors[0]')"
    exit 1
fi

DATA_BLOCK=$(echo $JSON_RESPONSE | jq -r '.data.data')

if [ "$DATA_BLOCK" == "null" ]; then
    echo "❌ ERRO: Nenhum segredo encontrado ou caminho incorreto."
    exit 1
fi

echo "📝 [ENV] Gerando arquivo .env..."

echo "$DATA_BLOCK" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' > .env

echo "HOST_GIT_DIR=$HOST_GIT_DIR" >> .env
echo "HOST_BACKUP_DIR=$HOST_BACKUP_DIR" >> .env

echo "   - Variáveis injetadas:"
cat .env | cut -d '=' -f 1 | sed 's/^/   * /'

echo "🚀 [DOCKER] Iniciando serviço..."
docker compose up -d

rm .env