FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install --global pnpm@11.16.0 \
    && pnpm install --prod --frozen-lockfile \
    && pnpm store prune \
    && npm cache clean --force

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S shareittoo && adduser -S -G shareittoo shareittoo
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY sql ./sql
COPY src ./src
RUN mkdir -p /data/uploads && chown -R shareittoo:shareittoo /app /data
USER shareittoo
EXPOSE 8080
CMD ["node", "src/server.js"]
