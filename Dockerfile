FROM alpine
MAINTAINER zjuvis@gmail.com

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && apk update --no-cache && apk add supervisor iproute2 bind-tools socat
COPY delegated /usr/bin/delegated
COPY proxy.sh /proxy.sh
ENTRYPOINT /proxy.sh

