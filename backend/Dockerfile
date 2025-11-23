FROM node:20-alpine AS base

# Create app directory
WORKDIR /usr/src/app

# Copy dependency definitions
COPY package*.json ./

# Install the required dependencies
RUN npm ci --omit=dev

# Get all the code needed to run the app
COPY . .

# Expose the port the app runs in
EXPOSE 5001

# Serve the app
CMD ["npm", "start"]