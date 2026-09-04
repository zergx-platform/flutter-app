# syntax=docker/dockerfile:1
ARG REGISTRY=jj-lab.temp.svc.cluster.local
FROM ${REGISTRY}/library/nginx:stable-alpine

COPY build/web /usr/share/nginx/html

# SPA: Flutter web uses hash-free flat files; unknown paths fall back to /.
RUN printf 'server {\n    listen       8080;\n    server_name  localhost;\n    root   /usr/share/nginx/html;\n    index  index.html;\n    location / {\n        try_files $uri $uri/ /index.html;\n    }\n    location = /api/v1/health { return 200 "{\\"ok\\":true,\\"name\\":\\"zergx-flutter\\"}"; }\n}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 8080