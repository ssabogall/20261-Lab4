FROM node:20-alpine AS base

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

EXPOSE 5002

CMD ["npm", "start"]
