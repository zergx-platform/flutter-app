FROM artifact.zergx.svc.cluster.local/library/nginx:stable-alpine
COPY zergx-app-release.apk /usr/share/nginx/html/zergx-app-release.apk
COPY index.html /usr/share/nginx/html/index.html
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80