#!/bin/bash

unset_and_exit() {
    export SERVICE_NAME=""
    export CI_ENVIRONMENT=""
    export CI_NAMESPACE=""
    export ENV_FILE=""
    export VALUES_PATH=""
    unset unset_and_exit
    exit 0
}

if [ ! -z "$ENV_FILE" ]; then
    . "$ENV_FILE"
else
    . ./env
fi

# Verify we are in a service 
if [ -z "$SERVICE_NAME" ]; then
    echo "SERVICE_NAME Not set"
    exit 1
fi

# Verify we have values
if [ -z "$VALUES_PATH" ]; then
    echo "VALUES_PATH Not set"
    exit 1
fi

echo Service Name: $VALUES_PATH
echo Service Location: `pwd`
echo Using Context: `kubectl config current-context`

if [[ "${CI_ASSUME_YES:-false}" == "true" ]]; then
    input="y"
elif [[ -t 0 ]]; then
    read -r -p "Is the Above Correct? [y/N] " input
else
    echo "Non-interactive shell detected. Set CI_ASSUME_YES=true to proceed."
    unset_and_exit
fi

case $input in
      [yY][eE][sS]|[yY])
            helm dependencies update $VALUES_PATH
            unset_and_exit
            ;;
      *)
            unset_and_exit
            ;;
esac