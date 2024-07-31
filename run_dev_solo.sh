#!/bin/sh

# redis 启动
# docker work， 微信云托管的redis需要手动启动，cmd启动不了
# redis-server &
# work
# redis-server /app/conf/redis.conf &
# work
redis-server /app/dockerconf/redis.conf & # >> ./storage/redis_server_start_log.txt 2>&1

# 后台启动
php-fpm -D
# 关闭后台启动，hold住进程
nginx -g 'daemon off;'


