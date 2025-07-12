#!/bin/bash

# ============================================
# SCRIPT DE DEPLOY PARA PRODUÇÃO
# OneWay Rent A Car - Deploy Automatizado
# ============================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    print_status "Verificando se Docker está rodando..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker não está rodando. Inicie o Docker e tente novamente."
        exit 1
    fi
    print_success "Docker está rodando"
}

# Create external network if it doesn't exist
create_network() {
    print_status "Criando rede externa do Traefik..."
    if ! docker network ls | grep -q "traefik"; then
        docker network create traefik
        print_success "Rede 'traefik' criada"
    else
        print_warning "Rede 'traefik' já existe"
    fi
}

# Load environment variables
load_env() {
    print_status "Carregando variáveis de ambiente..."
    if [ -f .env.production ]; then
        export $(cat .env.production | xargs)
        print_success "Variáveis de ambiente carregadas"
    else
        print_warning "Arquivo .env.production não encontrado, usando valores padrão"
    fi
}

# Build the application
build_app() {
    print_status "Fazendo build da aplicação..."
    
    # Clean previous builds
    rm -rf dist/
    
    # Install dependencies and build
    npm ci --only=production
    npm run build
    
    print_success "Build da aplicação concluído"
}

# Build Docker images
build_docker() {
    print_status "Fazendo build das imagens Docker..."
    
    # Build production image
    docker build \
        --file Dockerfile.production \
        --target production \
        --build-arg NODE_ENV=production \
        --build-arg VITE_SUPABASE_URL="${VITE_SUPABASE_URL}" \
        --build-arg VITE_SUPABASE_ANON_KEY="${VITE_SUPABASE_ANON_KEY}" \
        --tag oneway-rent-car:latest \
        --tag oneway-rent-car:$(date +%Y%m%d_%H%M%S) \
        .
    
    print_success "Imagens Docker criadas"
}

# Deploy with Docker Compose
deploy() {
    print_status "Fazendo deploy da aplicação..."
    
    # Stop existing containers
    docker-compose -f docker-compose.production.yml down --remove-orphans
    
    # Start new containers
    docker-compose -f docker-compose.production.yml up -d --build
    
    print_success "Deploy concluído"
}

# Wait for health check
wait_for_health() {
    print_status "Aguardando aplicação ficar saudável..."
    
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f http://localhost/health > /dev/null 2>&1; then
            print_success "Aplicação está saudável"
            return 0
        fi
        
        attempt=$((attempt + 1))
        print_status "Tentativa $attempt/$max_attempts..."
        sleep 5
    done
    
    print_error "Aplicação não ficou saudável após $max_attempts tentativas"
    return 1
}

# Show access information
show_access_info() {
    print_success "Deploy concluído com sucesso!"
    echo ""
    echo "📱 COMO ACESSAR:"
    echo "   • Local: http://localhost"
    echo "   • Rede local: http://oneway.local"
    echo "   • IP da máquina: http://$(hostname -I | awk '{print $1}')"
    echo ""
    echo "🔧 FERRAMENTAS:"
    echo "   • Traefik Dashboard: http://localhost:8080"
    echo "   • Health Check: http://localhost/health"
    echo ""
    echo "📋 COMANDOS ÚTEIS:"
    echo "   • Ver logs: docker-compose -f docker-compose.production.yml logs -f"
    echo "   • Parar: docker-compose -f docker-compose.production.yml down"
    echo "   • Reiniciar: docker-compose -f docker-compose.production.yml restart"
    echo ""
}

# Main execution
main() {
    print_status "🚀 Iniciando deploy de produção OneWay Rent A Car..."
    echo ""
    
    check_docker
    create_network
    load_env
    build_app
    build_docker
    deploy
    wait_for_health
    show_access_info
    
    print_success "🎉 Deploy de produção concluído com sucesso!"
}

# Run main function
main "$@" 