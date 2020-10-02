# Convenience wrapper for minikube docker env setup
minikube_docker_env() {
    if hash minikube 2>/dev/null; then
        eval "$(minikube docker-env)"
    else
        echo "can't find chef executeable!"
        return 1
    fi
}
