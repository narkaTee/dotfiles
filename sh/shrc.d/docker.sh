docker_purge() {
    docker ps -a -q | xargs --no-run-if-empty docker rm
    docker images -q | xargs --no-run-if-empty docker rmi -f
    docker volume prune -f
    docker network prune -f
}
