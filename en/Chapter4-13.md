##4.13 SDIO WiFi

This example demonstrates the feasibility of verifying SDIO Wi-Fi drivers through related commands.There is a SDIO WiFi wireless card in development board, Through the relevant configuration after the implementation of wireless networking capabilities.

**Hardware Preparation：**
  * Hardware debugging environment to see chapter second.
  * MYD-AM335X-Y development board

> **Note：MYD-AM335X and MYD-AM335X-J no onboard SDIO, SDIO Wi-Fi information please click[SDIO WiFi](http://www.myir-tech.com/product/MY-WF004S.htm).**

**Software Preparation:**
  * Linux Kernel 4.1.18
  * wpa_supplicant applicatoin
  * wpa_cli applicatoin

**Test Steps:**
  * After the MYD-AM335X-Y development is booted, Run the following command on the development board:

```c
# ifconfig eth0 down
# wpa_supplicant -iwlan0 -Dwext -B -c /etc/wpa_supplicant.conf
```

* Use wpa_cli to configure the network:

```c
# wpa_cli
> scan
OK
> scan_r
> scan_r
bssid / frequency / signal level / flags / ssid
30:fc:68:9a:e8:99       2412    -43     [WPA-PSK-CCMP][WPA2-PSK-CCMP][ESS]      MYIR_TECH
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

* Get IP address by DHCP:

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

* Check whether the network is connected by Ping server:

```c
# ping 192.168.30.137
PING 192.168.30.137 (192.168.30.137): 56 data bytes
64 bytes from 192.168.30.137: seq=0 ttl=64 time=75.532 ms
64 bytes from 192.168.30.137: seq=1 ttl=64 time=4.074 ms
64 bytes from 192.168.30.137: seq=2 ttl=64 time=3.461 ms
64 bytes from 192.168.30.137: seq=3 ttl=64 time=12.684 ms
64 bytes from 192.168.30.137: seq=4 ttl=64 time=11.986 ms
```

