# Script para verificar configuração SSL (PowerShell)
param(
    [string]$Domain = "onewaycargo.com.br"
)

$CertPath = "/etc/letsencrypt/live/$Domain"

Write-Host "🔍 Verificando configuração SSL para $Domain" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Gray

# 1. Verificar se o certificado existe
Write-Host "1. Verificando certificado SSL..." -ForegroundColor Yellow
if (Test-Path "$CertPath/fullchain.pem") {
    Write-Host "✅ Certificado encontrado: $CertPath/fullchain.pem" -ForegroundColor Green
    
    # Verificar validade (simplificado para Windows)
    try {
        $cert = Get-ChildItem "$CertPath/fullchain.pem" -ErrorAction Stop
        Write-Host "📅 Certificado encontrado em: $($cert.LastWriteTime)" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Não foi possível verificar detalhes do certificado" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Certificado não encontrado em $CertPath" -ForegroundColor Red
}

Write-Host ""

# 2. Verificar se o container está rodando
Write-Host "2. Verificando container Docker..." -ForegroundColor Yellow
$container = docker ps --format "table {{.Names}}\t{{.Ports}}" | Select-String "oneway-app"
if ($container) {
    Write-Host "✅ Container oneway-app está rodando" -ForegroundColor Green
    
    # Verificar portas
    if ($container -match "80") {
        Write-Host "✅ Porta 80 mapeada" -ForegroundColor Green
    } else {
        Write-Host "❌ Porta 80 não mapeada" -ForegroundColor Red
    }
    
    if ($container -match "443") {
        Write-Host "✅ Porta 443 mapeada" -ForegroundColor Green
    } else {
        Write-Host "❌ Porta 443 não mapeada" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Container oneway-app não está rodando" -ForegroundColor Red
}

Write-Host ""

# 3. Testar conectividade HTTP
Write-Host "3. Testando redirecionamento HTTP → HTTPS..." -ForegroundColor Yellow
try {
    $httpResponse = Invoke-WebRequest -Uri "http://$Domain" -Method Head -UseBasicParsing -ErrorAction Stop
    if ($httpResponse.StatusCode -eq 301 -or $httpResponse.StatusCode -eq 302) {
        Write-Host "✅ HTTP redireciona corretamente (Status: $($httpResponse.StatusCode))" -ForegroundColor Green
    } else {
        Write-Host "❌ HTTP não redireciona corretamente (Status: $($httpResponse.StatusCode))" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erro ao testar HTTP: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Testar conectividade HTTPS
Write-Host "4. Testando HTTPS..." -ForegroundColor Yellow
try {
    $httpsResponse = Invoke-WebRequest -Uri "https://$Domain" -Method Head -UseBasicParsing -ErrorAction Stop
    if ($httpsResponse.StatusCode -eq 200) {
        Write-Host "✅ HTTPS funcionando corretamente (Status: $($httpsResponse.StatusCode))" -ForegroundColor Green
    } else {
        Write-Host "❌ HTTPS não funcionando (Status: $($httpsResponse.StatusCode))" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erro ao testar HTTPS: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 5. Verificar certificado SSL
Write-Host "5. Verificando certificado SSL..." -ForegroundColor Yellow
try {
    $sslResponse = Invoke-WebRequest -Uri "https://$Domain" -UseBasicParsing -ErrorAction Stop
    if ($sslResponse.BaseResponse) {
        Write-Host "✅ Certificado SSL válido" -ForegroundColor Green
        Write-Host "📋 Protocolo: $($sslResponse.BaseResponse.ProtocolVersion)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Erro ao verificar certificado SSL: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 6. Verificar configuração nginx
Write-Host "6. Verificando configuração Nginx..." -ForegroundColor Yellow
try {
    $nginxTest = docker exec oneway-app nginx -t 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Configuração Nginx válida" -ForegroundColor Green
    } else {
        Write-Host "❌ Erro na configuração Nginx" -ForegroundColor Red
        Write-Host $nginxTest -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erro ao verificar Nginx: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Gray
Write-Host "🔍 Verificação concluída!" -ForegroundColor Cyan

# Resumo final
Write-Host ""
Write-Host "📊 RESUMO:" -ForegroundColor Yellow
if ((Test-Path "$CertPath/fullchain.pem") -and $httpsResponse.StatusCode -eq 200) {
    Write-Host "✅ SSL configurado corretamente" -ForegroundColor Green
    Write-Host "🌐 Acesse: https://$Domain" -ForegroundColor Cyan
} else {
    Write-Host "❌ SSL não configurado corretamente" -ForegroundColor Red
    Write-Host "📖 Consulte o arquivo SSL_SETUP.md para instruções" -ForegroundColor Yellow
} 