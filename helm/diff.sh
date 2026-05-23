#!/bin/bash -e

unset_and_exit() {
    exit_code="${1:-0}"
    export SERVICE_NAME=""
    export CI_ENVIRONMENT=""
    export CI_NAMESPACE=""
    export ENV_FILE=""
    export VALUES_PATH=""
    unset unset_and_exit
    exit "${exit_code}"
}

if [ ! -z "$ENV_FILE" ]; then
    source "$ENV_FILE"
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

# Verify we have environment suffix for values override file
if [ -z "$CI_ENVIRONMENT" ]; then
    echo "CI_ENVIRONMENT Not set (expected values-\$CI_ENVIRONMENT.yaml)"
    exit 1
fi

echo Service Name: $SERVICE_NAME
echo Values Name: $VALUES_PATH
echo Service Location: `pwd`
echo Using Context: `kubectl config current-context`

if [[ "${CI_ASSUME_YES:-false}" == "true" ]]; then
    input="y"
elif [[ -t 0 ]]; then
    read -r -p "Is the Above Correct? [y/N] " input
else
    echo "Non-interactive shell detected. Set CI_ASSUME_YES=true to proceed." >&2
    unset_and_exit 1
fi

case $input in
      [yY][eE][sS]|[yY])
            helm diff upgrade --debug --namespace $CI_NAMESPACE --allow-unreleased $SERVICE_NAME $VALUES_PATH -f $VALUES_PATH/values.yaml -f $VALUES_PATH/values-$CI_ENVIRONMENT.yaml
            unset_and_exit
            ;;
      *)
            unset_and_exit
            ;;
esac
