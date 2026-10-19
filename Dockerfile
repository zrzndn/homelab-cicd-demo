FROM nginx:alpine

ARG APP_VERSION=dev
COPY index.html /usr/share/nginx/html/index.html
COPY health.html /usr/share/nginx/html/health

# Embed the immutable release tag in the built artifact for verification and rollback demos.
RUN sed -i "s|__APP_VERSION__|${APP_VERSION}|g" /usr/share/nginx/html/index.html
