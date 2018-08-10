# 一键安装 SSR 后端

* 适用于 `Ubuntu 16/18` `Debian 8/9` 64bit 系统
* 将会安装 `nginx` `php` `python` `nodejs` 环境
* 升级内核并开启 `BBR`
* 安装 SSR 魔改版后端并开启守护

## 使用方法
```
wget --no-check-certificate https://raw.githubusercontent.com/S8Cloud/installSS/master/setup.sh
bash setup.sh
```
如果更换内核会自动重启，重启后：
```
bash setup.sh bbr
bash setup.sh ssr 
```
