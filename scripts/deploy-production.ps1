# ============================================
# SCRIPT DE DEPLOY PARA PRODUÇÃO - WINDOWS
# OneWay Rent A Car - Deploy Automatizado
# ============================================

param(
    [switch]$Force,
    [string]$Environment = "production"
)

# Configurações
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Função para log colorido
function Write-Info($Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success($Message) {
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning($Message) {
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error($Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Verificar se Docker está rodando
function Test-Docker {
    Write-Info "Verificando se Docker está rodando..."
    try {
        docker info | Out-Null
        Write-Success "Docker está rodando"
        return $true
    }
    catch {
        Write-Error "Docker não está rodando. Inicie o Docker e tente novamente."
        return $false
    }
}

# Criar rede externa
function New-DockerNetwork {
    Write-Info "Criando rede externa do Traefik..."
    
    $networks = docker network ls --format "table {{.Name}}" | Select-String "traefik"
    
    if (-not $networks) {
        docker network create traefik
        Write-Success "Rede 'traefik' criada"
    }
    else {
        Write-Warning "Rede 'traefik' já existe"
    }
}

# Carregar variáveis de ambiente
function Import-EnvironmentVariables {
    Write-Info "Carregando variáveis de ambiente..."
    
    if (Test-Path ".env.production") {
        Get-Content ".env.production" | ForEach-Object {
            if ($_ -match "^([^#][^=]+)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            }
        }
        Write-Success "Variáveis de ambiente carregadas"
    }
    else {
        Write-Warning "Arquivo .env.production não encontrado, usando valores padrão"
    }
}

# Build da aplicação
function Build-Application {
    Write-Info "Fazendo build da aplicação..."
    
    # Limpar builds anteriores
    if (Test-Path "dist") {
        Remove-Item -Recurse -Force "dist"
    }
    
    # Instalar dependências e fazer build
    npm ci --only=production --silent
    npm run build
    
    Write-Success "Build da aplicação concluído"
}

# Build das imagens Docker
function Build-DockerImages {
    Write-Info "Fazendo build das imagens Docker..."
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $supabaseUrl = [Environment]::GetEnvironmentVariable("VITE_SUPABASE_URL") ?? "https://bdcqaeppqnwixhumfsso.supabase.co"
    $supabaseKey = [Environment]::GetEnvironmentVariable("VITE_SUPABASE_ANON_KEY") ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJkY3FhZXBwcW53aXhodW1mc3NvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMTM0MTcsImV4cCI6MjA2Njc4OTQxN30.p0BSXUgjstOMOuli_Ko7Kf8Z-T7fb5ozp9qWr-tK_tc"
    
    docker build `
        --file Dockerfile.production `
        --target production `
        --build-arg NODE_ENV=production `
        --build-arg VITE_SUPABASE_URL="$supabaseUrl" `
        --build-arg VITE_SUPABASE_ANON_KEY="$supabaseKey" `
        --tag oneway-rent-car:latest `
        --tag "oneway-rent-car:$timestamp" `
        .
    
    Write-Success "Imagens Docker criadas"
}

# Deploy com Docker Compose
function Start-Deployment {
    Write-Info "Fazendo deploy da aplicação..."
    
    # Parar containers existentes
    docker-compose -f docker-compose.production.yml down --remove-orphans
    
    # Iniciar novos containers
    docker-compose -f docker-compose.production.yml up -d --build
    
    Write-Success "Deploy concluído"
}

# Aguardar health check
function Wait-ForHealth {
    Write-Info "Aguardando aplicação ficar saudável..."
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Success "Aplicação está saudável"
                return $true
            }
        }
        catch {
            # Ignorar erros durante o processo de espera
        }
        
        $attempt++
        Write-Info "Tentativa $attempt/$maxAttempts..."
        Start-Sleep -Seconds 5
    }
    
    Write-Error "Aplicação não ficou saudável após $maxAttempts tentativas"
    return $false
}

# Obter IP local
function Get-LocalIP {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*" | Where-Object { $_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" }).IPAddress | Select-Object -First 1
        if (-not $ip) {
            $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" }).IPAddress | Select-Object -First 1
        }
        return $ip ?? "localhost"
    }
    catch {
        return "localhost"
    }
}

# Mostrar informações de acesso
function Show-AccessInfo {
    $localIP = Get-LocalIP
    
    Write-Success "Deploy concluído com sucesso!"
    Write-Host ""
    Write-Host "📱 COMO ACESSAR:" -ForegroundColor Cyan
    Write-Host "   • Local: http://localhost" -ForegroundColor White
    Write-Host "   • Rede local: http://oneway.local" -ForegroundColor White
    Write-Host "   • IP da máquina: http://$localIP" -ForegroundColor White
    Write-Host "   • Traefik: oneway-onewayrentacar-*.traefik.me" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 FERRAMENTAS:" -ForegroundColor Cyan
    Write-Host "   • Traefik Dashboard: http://localhost:8080" -ForegroundColor White
    Write-Host "   • Health Check: http://localhost/health" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 COMANDOS ÚTEIS:" -ForegroundColor Cyan
    Write-Host "   • Ver logs: docker-compose -f docker-compose.production.yml logs -f" -ForegroundColor White
    Write-Host "   • Parar: docker-compose -f docker-compose.production.yml down" -ForegroundColor White
    Write-Host "   • Reiniciar: docker-compose -f docker-compose.production.yml restart" -ForegroundColor White
    Write-Host ""
    Write-Host "📱 CONFIGURAÇÃO MOBILE:" -ForegroundColor Cyan
    Write-Host "   1. Conecte o celular no mesmo Wi-Fi" -ForegroundColor White
    Write-Host "   2. Acesse http://$localIP no mobile" -ForegroundColor White
    Write-Host "   3. Ou configure DNS do mobile para $localIP e acesse http://oneway.local" -ForegroundColor White
    Write-Host ""
}

# Função principal
function Start-ProductionDeploy {
    Write-Info "🚀 Iniciando deploy de produção OneWay Rent A Car..."
    Write-Host ""
    
    if (-not (Test-Docker)) {
        exit 1
    }
    
    New-DockerNetwork
    Import-EnvironmentVariables
    Build-Application
    Build-DockerImages
    Start-Deployment
    
    if (Wait-ForHealth) {
        Show-AccessInfo
        Write-Success "🎉 Deploy de produção concluído com sucesso!"
    }
    else {
        Write-Error "Deploy falhou - aplicação não ficou saudável"
        exit 1
    }
}

# Executar se o script foi chamado diretamente
if ($MyInvocation.InvocationName -ne '.') {
    Start-ProductionDeploy
} 