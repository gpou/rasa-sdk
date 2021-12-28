#!/bin/bash

set -Eeuo pipefail

function print_help {
    echo "Available options:"
    echo " start  - Start Rasa Action Server"
    echo " help   - Print this help"
    echo " run    - Run an arbitrary command inside the container"
}

case ${1} in
    start)
        exec java -jar /usr/local/kogito-apps-jitrunner-improvements/jitexecutor/jitexecutor-runner/target/jitexecutor-runner-2.0.0-SNAPSHOT-runner.jar & python -m rasa_sdk "${@:2}"
        ;;
    run)
        exec "${@:2}"
        ;;
    *)
        print_help
        ;;
esac
