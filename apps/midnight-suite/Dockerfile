FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Install dependencies
RUN npm install -g pnpm && \
    pnpm install --frozen-lockfile

# Copy application code
COPY . .

# Expose default port
EXPOSE 3000

# Default command
CMD ["pnpm", "run", "night:dust"]
