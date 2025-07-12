# ============================================
# DOCKERFILE DE PRODUÇÃO - ONEWAY RENT A CAR
# ============================================

# Stage 1: Build da aplicação
FROM node:18-alpine AS build

# Definir diretório de trabalho
WORKDIR /app

# Instalar dependências do sistema necessárias
RUN apk add --no-cache \
    curl \
    wget \
    git

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar todas as dependências (incluindo dev para build)
RUN npm ci --silent

# Copiar código fonte
COPY . .

# Build arguments para ambiente
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ARG NODE_ENV=production

# Definir variáveis de ambiente de build
ENV NODE_ENV=$NODE_ENV
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY

# Build da aplicação otimizada para produção
RUN npm run build

# Verificar se o build foi bem-sucedido
RUN test -d dist && echo "✅ Build successful" || (echo "❌ Build failed" && exit 1)

# Stage 2: Nginx de produção
FROM nginx:1.25-alpine AS production

# Instalar dependências necessárias
RUN apk add --no-cache \
    curl \
    wget \
    tzdata \
    ca-certificates

# Configurar timezone
ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Criar usuário não-root para segurança
RUN addgroup -g 1001 -S nginx-user && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx-user -g nginx-user nginx-user

# Configurar diretórios
RUN mkdir -p /usr/share/nginx/html /var/log/nginx /etc/nginx/conf.d

# Copiar arquivos do build
COPY --from=build --chown=nginx-user:nginx-user /app/dist /usr/share/nginx/html

# Copiar configuração nginx otimizada
COPY --chown=nginx-user:nginx-user nginx.conf /etc/nginx/nginx.conf

# Criar arquivo de health check
RUN echo '{"status":"ok","app":"oneway-rent-car","timestamp":"'$(date -Iseconds)'"}' > /usr/share/nginx/html/health.json

# Configurar permissões de segurança
RUN chown -R nginx-user:nginx-user /usr/share/nginx/html /var/log/nginx /etc/nginx && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod 644 /etc/nginx/nginx.conf

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Expor porta
EXPOSE 80

# Labels para identificação
LABEL maintainer="OneWay Rent A Car"
LABEL version="1.0"
LABEL description="Sistema de Gestão para Locadora de Veículos"

# Executar como usuário não-root
USER nginx-user

# Comando de inicialização
CMD ["nginx", "-g", "daemon off;"] 