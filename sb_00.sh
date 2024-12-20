#!/bin/bash

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }

USERNAME=$(whoami)
HOSTNAME=$(hostname)
export UUID=${UUID:-'bc97f674-c578-4940-9234-0a1da46041b9'}

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="domains/${USERNAME}.ct8.pl/logs" || WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")
ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1

install_singbox() {
    echo -e "${yellow}本脚本同时三协议共存${purple}(vless-reality|hysteria2|tuic)${re}"
    echo -e "${yellow}开始运行前，请确保在面板${purple}已开放3个端口，一个tcp端口和两个udp端口${re}"
    echo -e "${yellow}面板${purple}Additional services中的Run your own applications${yellow}已开启为${purplw}Enabled${yellow}状态${re}"

    cd $WORKDIR

    ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
    if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
    elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    declare -A FILE_MAP
    generate_random_name() {
        local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
        local name=""
        for i in {1..6}; do
            name="$name${chars:RANDOM%${#chars}:1}"
        done
        echo "$name"
    }

    download_with_fallback() {
        local URL=$1
        local NEW_FILENAME=$2

        curl -L -sS --max-time 2 -o "$NEW_FILENAME" "$URL" &
        CURL_PID=$!
        CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
        
        sleep 1
        CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
        
        if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
            kill $CURL_PID 2>/dev/null
            wait $CURL_PID 2>/dev/null
            wget -q -O "$NEW_FILENAME" "$URL"
            echo -e "\e[1;32mDownloading $NEW_FILENAME by wget\e[0m"
        else
            wait $CURL_PID
            echo -e "\e[1;32mDownloading $NEW_FILENAME by curl\e[0m"
        fi
    }

    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        RANDOM_NAME=$(generate_random_name)
        NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
        
        if [ -e "$NEW_FILENAME" ]; then
            echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
        else
            download_with_fallback "$URL" "$NEW_FILENAME"
        fi
        
        chmod +x "$NEW_FILENAME"
        FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
    done
    wait

    output=$(./"$(basename ${FILE_MAP[web]})" generate reality-keypair)
    private_key=$(echo "${output}" | awk '/PrivateKey:/ {print $2}')
    public_key=$(echo "${output}" | awk '/PublicKey:/ {print $2}')

    openssl ecparam -genkey -name prime256v1 -out "private.key"
    openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

    cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "strategy": "ipv4_only",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "geosite-openai"
        ],
        "server": "wireguard"
      },
      {
        "rule_set": [
          "geosite-netflix"
        ],
        "server": "wireguard"
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "server": "block"
      }
    ],
    "final": "google",
    "strategy": "",
    "disable_cache": false,
    "disable_expire": false
  },
    "inbounds": [
    {
       "tag": "hysteria-in",
       "type": "hysteria2",
       "listen": "$IP",
       "listen_port": $HY2_PORT,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://bing.com",
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
    {
        "tag": "vless-reality-vesion",
        "type": "vless",
        "listen": "$IP",
        "listen_port": $VLESS_PORT,
        "users": [
            {
              "uuid": "$UUID",
              "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "www.cerebrium.ai",
            "reality": {
                "enabled": true,
                "handshake": {
                    "server": "www.cerebrium.ai",
                    "server_port": 443
                },
                "private_key": "$private_key",
                "short_id": [
                  ""
                ]
            }
        }
    },
    {
      "tag": "tuic-in",
      "type": "tuic",
      "listen": "$IP",
      "listen_port": $TUIC_PORT,
      "users": [
        {
          "uuid": "$UUID",
          "password": "admin123"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    }

 ],
    "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "162.159.195.100",
      "server_port": 4500,
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:83c7:b31f:5858:b3a8:c6b1/128"
      ],
      "private_key": "mPZo+V9qlrMGCZ7+E6z2NI6NOV34PD++TpAR09PtCWI=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [
        26,
        21,
        228
      ]
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": [
          "geosite-openai"
        ],
        "outbound": "wireguard-out"
      },
      {
        "rule_set": [
          "geosite-netflix"
        ],
        "outbound": "wireguard-out"
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "outbound": "block"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-netflix.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-openai",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/openai.srs",
        "download_detour": "direct"
      },      
      {
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ],
    "final": "direct"
   },
   "experimental": {
      "cache_file": {
      "path": "cache.db",
      "cache_id": "mycacheid",
      "store_fakeip": true
    }
  }
}
EOF

    if [ -e "$(basename ${FILE_MAP[web]})" ]; then
        nohup ./"$(basename ${FILE_MAP[web]})" run -c config.json >/dev/null 2>&1 &
        sleep 2
        pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && green "$(basename ${FILE_MAP[web]}) is running" || { red "$(basename ${FILE_MAP[web]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[web]})"; nohup ./"$(basename ${FILE_MAP[web]})" run -c config.json >/dev/null 2>&1 & }
    fi
    sleep 1
    rm -f "$(basename ${FILE_MAP[web]})"
}

get_ip() {
  ip=$(curl -s --max-time 1.5 ipv4.ip.sb)
  if [ -z "$ip" ]; then
    ip=$( [[ "$HOSTNAME" =~ ^s([0-9]|[1-2][0-9]|30)\.serv00\.com$ ]] && echo "cache${BASH_REMATCH[1]}.serv00.com" || echo "$HOSTNAME" )
  else
    url="https://www.toolsdaquan.com/toolapi/public/ipchecking/$ip/443"
    response=$(curl -s --location --max-time 3 --request GET "$url" --header 'Referer: https://www.toolsdaquan.com/ipcheck')
    if [ -z "$response" ] || ! echo "$response" | grep -q '"icmp":"success"'; then
        accessible=false
    else
        accessible=true
    fi
    if [ "$accessible" = false ]; then
        ip=$( [[ "$HOSTNAME" =~ ^s([0-9]|[1-2][0-9]|30)\.serv00\.com$ ]] && echo "cache${BASH_REMATCH[1]}.serv00.com" || echo "$ip" )
    fi
  fi
  echo "$ip"
}
if [[ "$(get_ip)" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    IP=$(get_ip)
else
    IP=$(host "$(get_ip)" | grep "has address" | awk '{print $4}')
fi

get_links(){
ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")
get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$ISP-$(get_name)"
yellow "注意：v2ray或其他软件的跳过证书验证需设置为true,否则hy2或tuic节点可能不通\n"
cat > list.txt <<EOF
vless://$UUID@$IP:$VLESS_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cerebrium.ai&fp=chrome&pbk=$public_key&type=tcp&headerType=none#$NAME-reality

hysteria2://$UUID@$IP:$HY2_PORT/?sni=www.bing.com&alpn=h3&insecure=1#$NAME-hy2

tuic://$UUID:admin123@$IP:$TUIC_PORT?sni=www.bing.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#$NAME-tuic
EOF
cat list.txt
purple "\n$WORKDIR/list.txt saved successfully"
purple "Running done!\n"
sleep 3 
rm -rf config.json sb.log core fake_useragent_0.2.0.json
}

# 检查环境变量并直接调用相应的函数
if [ -n "$VLESS_PORT" ] && [ -n "$HY2_PORT" ] && [ -n "$TUIC_PORT" ]; then
    install_singbox
    exit 0
fi

get_links
