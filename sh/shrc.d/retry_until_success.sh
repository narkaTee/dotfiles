# Working in an environment with flaky network?
# You are sick of running the same command over and over until it works?
retry_until_success() {
    $@
    status_code=$?
    while [ $status_code -gt 0 ]
    do
        echo
        echo "Status code '$status_code' Retrying in 2 sec..."
        sleep 2
        $@
        status_code=$?
    done
}
