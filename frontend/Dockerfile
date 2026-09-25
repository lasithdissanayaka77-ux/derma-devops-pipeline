# ================================
# DermaAI Frontend Dockerfile
# Vite + React + Nginx
# ================================

# ---------- Build stage ----------
FROM node:22-alpine AS build

WORKDIR /app

# Install dependencies first for better Docker layer caching
COPY package*.json ./

RUN npm ci --no-audit --no-fund

# Copy source code
COPY . .

# API URL used by the Vite production build
ARG VITE_API_URL=/api
ENV VITE_API_URL=$VITE_API_URL

# Build production frontend
RUN npm run build


# ---------- Production stage ----------
FROM nginx:stable-alpine

# Copy Nginx configuration template
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy compiled Vite application
COPY --from=build /app/dist /usr/share/nginx/html

# Backend service name inside Docker Compose network
ENV BACKEND_HOST=backend

# HTTP port
EXPOSE 80

# Container health check
# Use 127.0.0.1 instead of localhost
HEALTHCHECK --interval=15s --timeout=3s --retries=5 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1

# OCI metadata
ARG BUILD_VERSION=unknown
ARG BUILD_REVISION=unknown

LABEL org.opencontainers.image.version=$BUILD_VERSION
LABEL org.opencontainers.image.revision=$BUILD_REVISION
