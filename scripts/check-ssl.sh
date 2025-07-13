#!/bin/bash

# Script para verificar configuração SSL
set -e

DOMAIN="onewaycargo.com.br"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

echo "🔍 Verificando configuração SSL para $DOMAIN"
echo "================================================"

# 1. Verificar se o certificado existe
echo "1. Verificando certificado SSL..."
if [ -f "$CERT_PATH/fullchain.pem" ]; then
    echo "✅ Certificado encontrado: $CERT_PATH/fullchain.pem"
    
    # Verificar validade
    EXPIRY=$(openssl x509 -in "$CERT_PATH/fullchain.pem" -noout -enddate | cut -d= -f2)
    echo "📅 Data de expiração: $EXPIRY"
    
    # Verificar dias restantes
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -gt 30 ]; then
        echo "✅ Certificado válido por mais $DAYS_LEFT dias"
    elif [ $DAYS_LEFT -gt 7 ]; then
        echo "⚠️  Certificado expira em $DAYS_LEFT dias"
    else
        echo "❌ Certificado expira em $DAYS_LEFT dias - RENOVAR URGENTE!"
    fi
else
    echo "❌ Certificado não encontrado em $CERT_PATH"
fi

echo ""

# 2. Verificar se o container está rodando
echo "2. Verificando container Docker..."
if docker ps | grep -q "oneway-app"; then
    echo "✅ Container oneway-app está rodando"
    
    # Verificar portas
    if docker port oneway-app | grep -q "80"; then
        echo "✅ Porta 80 mapeada"
    else
        echo "❌ Porta 80 não mapeada"
    fi
    
    if docker port oneway-app | grep -q "443"; then
        echo "✅ Porta 443 mapeada"
    else
        echo "❌ Porta 443 não mapeada"
    fi
else
    echo "❌ Container oneway-app não está rodando"
fi

echo ""

# 3. Testar conectividade HTTP
echo "3. Testando redirecionamento HTTP → HTTPS..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    echo "✅ HTTP redireciona corretamente (Status: $HTTP_RESPONSE)"
else
    echo "❌ HTTP não redireciona corretamente (Status: $HTTP_RESPONSE)"
fi

# 4. Testar conectividade HTTPS
echo "4. Testando HTTPS..."
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN 2>/dev/null || echo "000")
if [ "$HTTPS_RESPONSE" = "200" ]; then
    echo "✅ HTTPS funcionando corretamente (Status: $HTTPS_RESPONSE)"
else
    echo "❌ HTTPS não funcionando (Status: $HTTPS_RESPONSE)"
fi

echo ""

# 5. Verificar certificado SSL
echo "5. Verificando certificado SSL..."
SSL_INFO=$(echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "Erro ao conectar")

if echo "$SSL_INFO" | grep -q "subject="; then
    echo "✅ Certificado SSL válido"
    echo "📋 Detalhes do certificado:"
    echo "$SSL_INFO" | sed 's/^/   /'
else
    echo "❌ Erro ao verificar certificado SSL"
    echo "$SSL_INFO"
fi

echo ""

# 6. Verificar configuração nginx
echo "6. Verificando configuração Nginx..."
if docker exec oneway-app nginx -t 2>/dev/null; then
    echo "✅ Configuração Nginx válida"
else
    echo "❌ Erro na configuração Nginx"
    docker exec oneway-app nginx -t 2>&1
fi

echo ""
echo "================================================"
echo "🔍 Verificação concluída!"

# Resumo final
echo ""
echo "📊 RESUMO:"
if [ -f "$CERT_PATH/fullchain.pem" ] && [ "$HTTPS_RESPONSE" = "200" ]; then
    echo "✅ SSL configurado corretamente"
    echo "🌐 Acesse: https://$DOMAIN"
else
    echo "❌ SSL não configurado corretamente"
    echo "📖 Consulte o arquivo SSL_SETUP.md para instruções"
fi 