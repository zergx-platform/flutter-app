FROM artifact.zergx.svc.cluster.local/library/nginx:stable-alpine
COPY zergx-arm64-v8a-release.apk zergx-armeabi-v7a-release.apk zergx-x86_64-release.apk /usr/share/nginx/html/
COPY index.html /usr/share/nginx/html/index.html
# The arch-detection map must live in the http context; the stock nginx image
# only includes conf.d in http, so ship it as a separate include file.
COPY default.map.conf /etc/nginx/conf.d/00-arch-map.conf
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
