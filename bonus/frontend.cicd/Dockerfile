# STAGE1: build the application
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
ARG VITE_API_URL=/api
ENV VITE_API_URL=${VITE_API_URL}
COPY . .
RUN npm run build

# STAGE 2: Run the application
FROM nginx:alpine AS runtime
# copy built application from builder stage to the Nginx html directory
COPY --from=builder /app/dist /usr/share/nginx/html
# copy custom nginx configuration file to the container
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s \ 
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1/healthz || exit 1