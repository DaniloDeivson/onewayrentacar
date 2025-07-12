#!/bin/bash

# Para o processo anterior do Vite (se estiver rodando)
pkill -f "vite" || true

# Garante as dependências
npm install

# Inicia o servidor de desenvolvimento ouvindo em todas as interfaces
npm run dev -- --host 