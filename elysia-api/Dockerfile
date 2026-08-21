FROM oven/bun:1.2-slim AS base
WORKDIR /app

# Install dependencies
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile --production

# Copy application source code
COPY . .

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Run native Elysia with Bun
CMD ["bun", "run", "src/index.ts"]
