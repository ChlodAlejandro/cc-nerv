FROM node:20-alpine
ENV NODE_ENV=production

# Disable npm update message
RUN npm config set update-notifier false

# ====================================
# Install dependencies
# ====================================
WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm -d ci

COPY . ./
ENV PORT 80
EXPOSE 80

CMD [ "node", "src/server.mjs" ]
