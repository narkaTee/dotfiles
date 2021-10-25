url_pattern='^(http|https):\/\/([^:]+):?([0-9]*)$'

extract_proxy_from_env() {
    local vars=("http_proxy" "HTTP_PROXY" "https_proxy" "HTTPS_PROXY")
    local proxy_url
    for var in $vars; do
        if [ -n "${!var}" ]; then
            proxy_url="${!var}"
            break
        fi
    done
    echo $proxy_url
}

extract_proxy_host() {
    echo "$(extract_proxy_from_env | sed -r "s/$url_pattern/\2/g")"
}

extract_proxy_port() {
    local proxy="$(extract_proxy_from_env)"
    local port
    if [[ "$proxy" =~ $url_pattern ]]; then
        port="${BASH_REMATCH[3]}"
    fi
    if [ -z "$port" ]; then
        case "$proxy" in
            "http:"*)
                port="80"
                ;;
            "https:"*)
                port="443"
                ;;
            *)
                >&2 echo "Unsupported proxy url: $proxy"
                exit 1
                ;;
        esac
    fi
    echo "$port"
}

# uses corkscrew to tunnel ssh through a http proxy
sshp() {
    local proxy_host proxy_port local_port
    proxy_host="$(extract_proxy_host)"
    proxy_port="$(extract_proxy_port)"
    corkscrew="$(which corkscrew)"
    if [ -z "$corkscrew" ]; then
        >&2 echo "corkscrew not found!"
        exit 1
    fi

    echo ssh -o "ProxyCommand '$corkscrew $proxy_host $proxy_port %h %p'" -o "ServerAliveInterval 30" $@
}
sshp

sshp_lp_usage() {
    echo "Usage:"
    echo "\t sshlp <local_port> <ssh options>"
    echo ""
    echo "Example:"
    echo "sshlp 8888 user@jump.host.tld -p 222"
}

# uses sshp to start a local socks proxy to pass traffic through an ssh tunnel
# usage: sshp 8888 jump.host.tld -p 222
# usage: sshp <local_proxy_port> <ssh params>
sshlp() {
    local_port="$1"
    if [ -z "$local_port" ]; then
        sshlp_usage
    fi
    shift

    echo "Starting ssh socks proxy on localhost:$local_port"
    echo "Urls:"
    echo "- socks4://localhost:$local_port"
    echo "- socks5://localhost:$local_port"
    echo ""

    sshp -ND "localhost:$local_port"
}
