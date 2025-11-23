FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependencies
COPY package*.json ./

# Install the required dependencies 
RUN npm ci

# Copy app files
COPY . .

# Build the front end app to be distributed
RUN npm run build

# Bundle static assets with nginx
FROM nginx:1.25-alpine AS development

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx template
COPY default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
