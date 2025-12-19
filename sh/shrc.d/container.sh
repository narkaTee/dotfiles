# shellcheck shell=sh
alias dc="docker compose"
alias mk=minikube
alias mkd=minikube_docker_env
alias kc=kubectl
alias kctx="kubectl config use-context"
alias kdbg="kubectl debug -it --share-processes --profile netadmin --image ghcr.io/narkatee/debug-container:latest"

docker_purge() {
    docker ps -a -q | xargs --no-run-if-empty docker rm
    docker images -q | xargs --no-run-if-empty docker rmi -f
    docker volume prune -f
    docker network prune -f
}

# Convenience wrapper for minikube docker env setup
minikube_docker_env() {
    if hash minikube 2>/dev/null; then
        eval "$(minikube docker-env)"
    else
        echo "can't find minikube executeable!"
        return 1
    fi
}
