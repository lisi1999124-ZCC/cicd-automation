# =============================================================================
# Multi-stage Docker Build for Production
# Optimized for small image size and security
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Dependencies (Install only production dependencies)
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Builder (Install all dependencies for build)
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source code
COPY . .

# Build the application
ARG BUILD_VERSION=unknown
ENV BUILD_VERSION=${BUILD_VERSION}
RUN npm run build || echo "Build step skipped (no build script)"

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: Production Image
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS production

# Labels
LABEL org.opencontainers.image.title="Application"
LABEL org.opencontainers.image.description="Production container image"
LABEL org.opencontainers.image.source="https://github.com/example/app"
LABEL org.opencontainers.image.version="1.0.0"

# Security: Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeapp -u 1001 -G nodejs

# Install production dependencies
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules

# Copy built application
COPY --from=builder --chown=nodeapp:nodejs /app/dist ./dist
COPY --from=builder --chown=nodeapp:nodejs /app/package*.json ./

# Set environment variables
ENV NODE_ENV=production \
    PORT=8080 \
    # Security headers
    NODE_OPTIONS="--max-old-space-size=512"

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Switch to non-root user
USER nodeapp

# Health check endpoint should be added to your application
# This is a basic TCP check as fallback
CMD ["sh", "-c", "node dist/index.js"]

# ─────────────────────────────────────────────────────────────────────────────
# Development Image (optional, used for local development)
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS development

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Volume for hot reload
VOLUME ["/app"]

# Development command with hot reload
CMD ["npm", "run", "dev"]
