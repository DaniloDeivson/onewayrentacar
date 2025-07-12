#!/bin/bash

# ============================================
# SCRIPT DE CONFIGURAÇÃO DE REDE
# OneWay Rent A Car - Setup de Rede Local
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
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

# Get local IP
get_local_ip() {
    # Try different methods to get local IP
    LOCAL_IP=""
    
    # Method 1: hostname -I (Linux)
    if command -v hostname >/dev/null 2>&1; then
        LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    fi
    
    # Method 2: ip route (Linux)
    if [ -z "$LOCAL_IP" ] && command -v ip >/dev/null 2>&1; then
        LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "")
    fi
    
    # Method 3: ifconfig (macOS/Linux)
    if [ -z "$LOCAL_IP" ] && command -v ifconfig >/dev/null 2>&1; then
        LOCAL_IP=$(ifconfig | grep -E "inet.*broadcast" | awk '{print $2}' | head -1 || echo "")
    fi
    
    # Method 4: Windows ipconfig (if on Windows)
    if [ -z "$LOCAL_IP" ] && command -v ipconfig.exe >/dev/null 2>&1; then
        LOCAL_IP=$(ipconfig.exe | grep -A 5 "Wireless LAN adapter Wi-Fi" | grep "IPv4 Address" | awk '{print $NF}' | tr -d '\r' || echo "")
    fi
    
    # Fallback
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="192.168.1.100"
        print_warning "Não foi possível detectar IP local, usando fallback: $LOCAL_IP"
    fi
    
    echo "$LOCAL_IP"
}

# Configure hosts file
configure_hosts() {
    print_info "Configurando arquivo hosts..."
    
    LOCAL_IP=$(get_local_ip)
    HOSTS_ENTRIES="
# OneWay Rent A Car - Local Development
$LOCAL_IP oneway.local
$LOCAL_IP app.oneway.local
$LOCAL_IP admin.oneway.local
$LOCAL_IP api.oneway.local
"
    
    # Check OS and configure hosts
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        # Linux/macOS
        HOSTS_FILE="/etc/hosts"
        
        # Backup hosts file
        sudo cp "$HOSTS_FILE" "${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Remove old entries
        sudo sed -i '/# OneWay Rent A Car/,/^$/d' "$HOSTS_FILE"
        
        # Add new entries
        echo "$HOSTS_ENTRIES" | sudo tee -a "$HOSTS_FILE" > /dev/null
        
        print_success "Arquivo hosts configurado em $HOSTS_FILE"
        
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows
        HOSTS_FILE="C:\\Windows\\System32\\drivers\\etc\\hosts"
        
        print_warning "No Windows, execute como Administrador:"
        echo "1. Abra o Prompt de Comando como Administrador"
        echo "2. Execute: notepad $HOSTS_FILE"
        echo "3. Adicione as seguintes linhas:"
        echo "$HOSTS_ENTRIES"
        
    else
        print_warning "Sistema operacional não reconhecido. Configure manualmente o arquivo hosts:"
        echo "$HOSTS_ENTRIES"
    fi
}

# Configure DNS (optional)
configure_dns() {
    print_info "Configurações de DNS (opcional)..."
    
    LOCAL_IP=$(get_local_ip)
    
    echo "Para melhor resolução DNS, configure seu roteador ou dispositivos para usar:"
    echo "  • DNS Primário: $LOCAL_IP"
    echo "  • DNS Secundário: 8.8.8.8"
    echo ""
    echo "Ou configure manualmente cada dispositivo:"
    echo "  • Android: Configurações > Wi-Fi > Modificar rede > Opções avançadas > DNS"
    echo "  • iOS: Configurações > Wi-Fi > (i) > Configurar DNS > Manual"
    echo "  • Windows: Painel de Controle > Rede > Alterar configurações do adaptador"
    echo ""
}

# Test network connectivity
test_connectivity() {
    print_info "Testando conectividade de rede..."
    
    LOCAL_IP=$(get_local_ip)
    
    # Test local IP
    if ping -c 1 "$LOCAL_IP" >/dev/null 2>&1; then
        print_success "IP local ($LOCAL_IP) está acessível"
    else
        print_error "IP local ($LOCAL_IP) não está acessível"
    fi
    
    # Test internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Conectividade com internet OK"
    else
        print_warning "Sem conectividade com internet"
    fi
    
    # Test DNS resolution
    if nslookup oneway.local >/dev/null 2>&1; then
        print_success "Resolução DNS local funcionando"
    else
        print_warning "Resolução DNS local não configurada"
    fi
}

# Show network information
show_network_info() {
    LOCAL_IP=$(get_local_ip)
    
    print_success "Configuração de rede concluída!"
    echo ""
    echo "🌐 INFORMAÇÕES DA REDE:"
    echo "   • IP Local: $LOCAL_IP"
    echo "   • Domínio Local: oneway.local"
    echo ""
    echo "📱 COMO ACESSAR DE OUTROS DISPOSITIVOS:"
    echo "   • http://$LOCAL_IP (direto pelo IP)"
    echo "   • http://oneway.local (se DNS configurado)"
    echo ""
    echo "🔧 CONFIGURAR DNS NOS DISPOSITIVOS MÓVEIS:"
    echo "   1. Conecte no mesmo Wi-Fi"
    echo "   2. Configure DNS para: $LOCAL_IP"
    echo "   3. Acesse: http://oneway.local"
    echo ""
    echo "🐳 PARA INICIAR A APLICAÇÃO:"
    echo "   • ./scripts/deploy-production.sh"
    echo "   • docker-compose -f docker-compose.production.yml up -d"
    echo ""
}

# Main execution
main() {
    print_info "🌐 Configurando rede para OneWay Rent A Car..."
    echo ""
    
    configure_hosts
    configure_dns
    test_connectivity
    show_network_info
    
    print_success "🎉 Configuração de rede concluída!"
}

# Check if running as script or sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 