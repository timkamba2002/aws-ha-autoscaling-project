# Multi-stage for smaller, more secure image
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY server.js ./
COPY package.json ./
EXPOSE 3000
ENV NODE_ENV=production
# Install wget for HEALTHCHECK (busybox variant is small); also useful for debugging in exec
RUN apk add --no-cache wget
# Simple healthcheck (also hits the /metrics-capable app)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/health || exit 1
CMD ["node", "server.js"]
