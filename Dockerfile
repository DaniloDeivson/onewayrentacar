# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies
RUN npm ci

# Copy source code
COPY . .

# Set environment variables for Supabase
ENV VITE_SUPABASE_URL=https://bdcqaeppqnwixhumfsso.supabase.co
ENV VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJkY3FhZXBwcW53aXhodW1mc3NvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMTM0MTcsImV4cCI6MjA2Njc4OTQxN30.p0BSXUgjstOMOuli_Ko7Kf8Z-T7fb5ozp9qWr-tK_tc

# Set executable permissions for node_modules binaries
RUN chmod +x node_modules/.bin/*

# Build the application usando o script padrão do package.json
RUN npm run build

# List contents of dist directory for debugging
RUN ls -la /app/dist/

# Production stage
FROM nginx:1.27-alpine AS production

# Garante que o diretório de destino existe
RUN mkdir -p /usr/share/nginx/html

# Copia os arquivos do build
COPY --from=build /app/dist /usr/share/nginx/html

# Copia a configuração customizada do nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Garante permissões corretas
RUN chmod -R 755 /usr/share/nginx/html

# Lista o conteúdo para debug
RUN ls -la /usr/share/nginx/html/

EXPOSE 80

# Comando padrão do Nginx para servir arquivos estáticos
CMD ["nginx", "-g", "daemon off;"]

# Development stage
FROM node:20-alpine AS dev
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
EXPOSE 80
CMD ["npm", "run", "build-and-dev", "--", "--host", "--port", "80"]