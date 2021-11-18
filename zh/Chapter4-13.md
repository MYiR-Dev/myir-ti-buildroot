##4.13 SDIO WiFi

本实例演示通过相关命令来验证SDIO Wi-Fi驱动的可行性。开发板上集成了一块SDIO无线网卡，通过相关配置后实行无线连网的功能。

**测试硬件环境：**
  * 硬件调试环境搭建见部署开发环境中的硬件调试环境搭建部分。
  * MYD-AM335X-Y开发板一块

> **注意：MYD-AM335X和MYD-AM335X-J无板载SDIO，详情点击[SDIO WiFi](http://www.myir-tech.com/product/MY-WF004S.htm)。**

**测试软件环境：**
  * Linux Kernel 4.1.18
  * wpa_supplicant 应用程序
  * wpa_cli 应用程序

**测试过程：**
&emsp;&emsp;开发板上的系统起来后，在开发板上运行如下命令：

```c
# ifconfig eth0 down
# wpa_supplicant -iwlan0 -Dwext -B -c /etc/wpa_supplicant.conf
```

&emsp;&emsp;使用wpa_cli配置网络：

```c
# wpa_cli
> scan
OK
> scan_r
> scan_r
bssid / frequency / signal level / flags / ssid
30:fc:68:9a:e8:99       2412    -43     [WPA-PSK-CCMP][WPA2-PSK-CCMP][ESS]
MYIR_TECH
> remove_n all
OK
> add_n
0
> set_n 0 ssid "MYIR_TECH"
OK
> set_n 0 psk "myir2016"
OK
> enable_n 0
OK
> quit
```

&emsp;&emsp;通过DHCP获取IP地址：

```c
# udhcpc -n -i wlan0
udhcpc: started, v1.25.1
udhcpc: sending discover
udhcpc: sending select for 192.168.30.140
udhcpc: lease of 192.168.30.140 obtained, lease time 3600
deleting routers
adding dns 223.5.5.5
adding dns 201.104.111.114
adding dns 114.114.114.114
```

&emsp;&emsp;通过ping server检查网络是否联通:

```c
# ping 192.168.30.137
PING 192.168.30.137 (192.168.30.137): 56 data bytes
64 bytes from 192.168.30.137: seq=0 ttl=64 time=75.532 ms
64 bytes from 192.168.30.137: seq=1 ttl=64 time=4.074 ms
64 bytes from 192.168.30.137: seq=2 ttl=64 time=3.461 ms
64 bytes from 192.168.30.137: seq=3 ttl=64 time=12.684 ms
64 bytes from 192.168.30.137: seq=4 ttl=64 time=11.986 ms
```
