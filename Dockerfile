# --- Stage 1: Build Stage ---
FROM node:18-alpine AS builder

WORKDIR /usr/src/app

# Копіюємо файли залежностей для кешування шарів
COPY package*.json ./

# Встановлюємо всі залежності (включаючи devDependencies для збірки, якщо є)
RUN npm ci

# Копіюємо вихідний код додатка
COPY . .

# Якщо є крок компіляції (наприклад, TypeScript), розкоментуйте рядок нижче:
# RUN npm run build

# Видаляємо devDependencies та залишаємо лише production пакети для зменшення розміру
RUN npm prune --production


# --- Stage 2: Production Stage ---
FROM node:18-alpine AS production

# Встановлюємо curl для роботи Docker Healthcheck
RUN apk add --no-cache curl

WORKDIR /usr/src/app

# Створюємо non-root користувача та групу для безпеки
RUN addgroup -g 1001 -S nodejs && \
    adduser -u 1001 -S nodeuser -G nodejs

# Копіюємо з першої стадії лише необхідні файли та production залежності
COPY --from=builder --chown=nodeuser:nodejs /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nodeuser:nodejs /usr/src/app/package*.json ./
COPY --from=builder --chown=nodeuser:nodejs /usr/src/app ./

# Перемикаємось на non-root користувача
USER nodeuser

EXPOSE 3000

ENV NODE_ENV=production

# Перевірка працездатності основного сервісу
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
