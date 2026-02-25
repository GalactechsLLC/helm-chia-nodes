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

# Verify we have environment suffix for values override file
if [ -z "$CI_ENVIRONMENT" ]; then
    echo "CI_ENVIRONMENT Not set (expected values-\$CI_ENVIRONMENT.yaml)"
    exit 1
fi

echo Service Name: $SERVICE_NAME
echo Values Path: $VALUES_PATH
echo Service Location: `pwd`
echo Using Context: `kubectl config current-context`

read -r -p "Is the Above Correct? [y/N] " input

case $input in
      [yY][eE][sS]|[yY])
            helm upgrade --install --namespace $CI_NAMESPACE $SERVICE_NAME $VALUES_PATH -f $VALUES_PATH/values.yaml -f $VALUES_PATH/values-$CI_ENVIRONMENT.yaml
            unset_and_exit
            ;;
      *)
            unset_and_exit
            ;;
esac
