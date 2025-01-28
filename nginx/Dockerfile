FROM ubuntu:focal

RUN \
    apt-get update && \
    apt-get install -y nginx && \
    echo "\ndaemon off;" >> /etc/nginx/nginx.conf
#EXPOSE 80
CMD ["nginx"]

