#!/bin/sh
## 仅限linux环境
ps -ef|grep server|grep -v grep|cut -c 9-15|xargs kill -9
exit 0