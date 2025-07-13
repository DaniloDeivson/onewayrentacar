#!/bin/bash

# Script de deploy para OneWay Cargo com SSL
set -e

echo "🚀 Iniciando deploy da OneWay Cargo com SSL..."

# Verificar se o certificado SSL existe
if [ ! -f "/etc/letsencrypt/live/onewaycargo.com.br/fullchain.pem" ]; then
    echo "❌ Certificado SSL não encontrado em /etc/letsencrypt/live/onewaycargo.com.br/"
    echo "Por favor, execute o certbot primeiro:"
    echo "sudo certbot certonly --standalone -d onewaycargo.com.br -d www.onewaycargo.com.br"
    exit 1
fi

echo "✅ Certificado SSL encontrado"

# Parar containers existentes
echo "🛑 Parando containers existentes..."
docker-compose down

# Rebuild da imagem
echo "🔨 Rebuild da imagem Docker..."
docker-compose build --no-cache

# Iniciar containers
echo "🚀 Iniciando containers..."
docker-compose up -d

# Verificar status
echo "📊 Verificando status dos containers..."
docker-compose ps

# Testar conectividade
echo "🔍 Testando conectividade..."
sleep 5

# Testar HTTP (deve redirecionar para HTTPS)
echo "Testando redirecionamento HTTP -> HTTPS..."
curl -I http://onewaycargo.com.br 2>/dev/null | head -1

# Testar HTTPS
echo "Testando HTTPS..."
curl -I https://onewaycargo.com.br 2>/dev/null | head -1

echo "✅ Deploy concluído com sucesso!"
echo "🌐 Aplicação disponível em: https://onewaycargo.com.br"
echo "📝 Logs disponíveis com: docker-compose logs -f" 