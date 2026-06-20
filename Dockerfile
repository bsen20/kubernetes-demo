FROM node:26-alpine AS base

WORKDIR /app

#install dependencies for caching
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
#copy source code
COPY . .

#Run as non-root user
USER node
EXPOSE 3000
ENV NODE_ENV=production
CMD ["npm", "start"]
