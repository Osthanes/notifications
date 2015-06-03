#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}
export -f debugme 
installwithpython27() {
    echo "Installing Python 2.7"
    sudo apt-get update &> /dev/null
    sudo apt-get -y install python2.7 &> /dev/null
    python --version 
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py &> /dev/null
    python get-pip.py --user &> /dev/null
    export PATH=$PATH:~/.local/bin
    if [ -f icecli-2.0.zip ]; then 
        debugme echo "there was an existing icecli.zip"
        debugme ls -la 
        rm -f icecli-2.0.zip
    fi 
    wget https://static-ice.ng.bluemix.net/icecli-2.0.zip &> /dev/null
    pip install --user icecli-2.0.zip > cli_install.log 2>&1 
    debugme cat cli_install.log 
}

if [[ $DEBUG = 1 ]]; then 
    export ICE_ARGS="--verbose"
else
    export ICE_ARGS=""
fi 

set +e
set +x 

###############################
# Configure extension PATH    #
###############################
if [ -n $EXT_DIR ]; then 
    export PATH=$EXT_DIR:$PATH
fi 

#########################################
# Configure log file to store errors  #
#########################################
if [ -z "$ERROR_LOG_FILE" ]; then
    ERROR_LOG_FILE="${EXT_DIR}/errors.log"
    export ERROR_LOG_FILE
fi

################################
# Setup archive information    #
################################
if [ -z $WORKSPACE ]; then 
    echo -e "${red}Please set WORKSPACE in the environment${no_color}"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

if [ -z $ARCHIVE_DIR ]; then 
    echo "${label_color}ARCHIVE_DIR was not set, setting to WORKSPACE/archive ${no_color}"
    export ARCHIVE_DIR="${WORKSPACE}"
fi 

if [ -d $ARCHIVE_DIR ]; then
  echo "Archiving to $ARCHIVE_DIR"
else 
  echo "Creating archive directory $ARCHIVE_DIR"
  mkdir $ARCHIVE_DIR 
fi 
export LOG_DIR=$ARCHIVE_DIR

######################
# Install ICE CLI    #
######################
echo "Installing IBM Container Service CLI"
ice help &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    installwithpython27
    ice help &> /dev/null
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to install IBM Container Service CLI ${no_color}"
        debugme python --version
        ${EXT_DIR}/print_help.sh
        exit $RESULT
    fi
    echo -e "${label_color}Successfully installed IBM Container Service CLI ${no_color}"
fi 

#############################
# Install Cloud Foundry CLI #
#############################
cf help &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "Installing Cloud Foundry CLI"
    pushd . 
    cd $EXT_DIR 
    gunzip cf-linux-amd64.tgz &> /dev/null
    tar -xvf cf-linux-amd64.tar  &> /dev/null
    cf help &> /dev/null
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Could not install the cloud foundry CLI ${no_color}"
        ${EXT_DIR}/print_help.sh    
        exit 1
    fi  
    popd
    echo -e "${label_color}Successfully installed Cloud Foundry CLI ${no_color}"
fi 

#################################
# Set Bluemix Host Information  #
#################################
if [ -n "$BLUEMIX_TARGET" ]; then
    if [ "$BLUEMIX_TARGET" == "staging" ]; then 
        export CCS_API_HOST="api-ice.stage1.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.stage1.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.stage1.ng.bluemix.net"
        export ICE_CFG="ice-cfg-staging.ini"
    elif [ "$BLUEMIX_TARGET" == "prod" ]; then 
        echo -e "Targetting production Bluemix"
        export CCS_API_HOST="api-ice.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.ng.bluemix.net"
        export ICE_CFG="ice-cfg-prod.ini"
    else 
        echo -e "${red}Unknown Bluemix environment specified"
    fi 
else 
    echo -e "Targetting production Bluemix"
    export CCS_API_HOST="api-ice.ng.bluemix.net" 
    export CCS_REGISTRY_HOST="registry-ice.ng.bluemix.net"
    export BLUEMIX_API_HOST="api.ng.bluemix.net"
    export ICE_CFG="ice-cfg-prod.ini"

fi  

################################
# Login to Container Service   #
################################
if [ -n "$API_KEY" ]; then 
    echo -e "${label_color}Logging on with API_KEY${no_color}"
    debugme echo "Login command: ice $ICE_ARGS login --key ${API_KEY}"
    #ice $ICE_ARGS login --key ${API_KEY} --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} 
    ice $ICE_ARGS login --key ${API_KEY} 2> /dev/null
    RESULT=$?
elif [ -n "$BLUEMIX_USER" ] || [ ! -f ~/.cf/config.json ]; then
    # need to gather information from the environment 
    # Get the Bluemix user and password information 
    if [ -z "$BLUEMIX_USER" ]; then 
        echo -e "${red} Please set BLUEMIX_USER on environment ${no_color} "
        ${EXT_DIR}/print_help.sh
        exit 1
    fi 
    if [ -z "$BLUEMIX_PASSWORD" ]; then 
        echo -e "${red} Please set BLUEMIX_PASSWORD as an environment property environment ${no_color} "
        ${EXT_DIR}/print_help.sh    
        exit 1 
    fi 
    if [ -z "$BLUEMIX_ORG" ]; then 
        export BLUEMIX_ORG=$BLUEMIX_USER
        echo -e "${label_color} Using ${BLUEMIX_ORG} for Bluemix organization, please set BLUEMIX_ORG if on the environment if you wish to change this. ${no_color} "
    fi 
    if [ -z "$BLUEMIX_SPACE" ]; then
        export BLUEMIX_SPACE="dev"
        echo -e "${label_color} Using ${BLUEMIX_SPACE} for Bluemix space, please set BLUEMIX_SPACE if on the environment if you wish to change this. ${no_color} "
    fi 
    echo -e "${label_color}Targetting information.  Can be updated by setting environment variables${no_color}"
    echo "BLUEMIX_USER: ${BLUEMIX_USER}"
    echo "BLUEMIX_SPACE: ${BLUEMIX_SPACE}"
    echo "BLUEMIX_ORG: ${BLUEMIX_ORG}"
    echo "BLUEMIX_PASSWORD: xxxxx"
    echo ""
    echo -e "${label_color}Logging in to Bluemix and IBM Container Service using environment properties${no_color}"
    debugme echo "login command: ice $ICE_ARGS login --cf --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE}"
    ice $ICE_ARGS login --cf --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE} 2> /dev/null
    RESULT=$?
else 
    # we are already logged in.  Simply check via ice command 
    echo -e "${label_color}Logging into IBM Container Service using credentials passed from IBM DevOps Services ${no_color}"
    mkdir -p ~/.ice
    debugme cat "${EXT_DIR}/${ICE_CFG}"
    cp ${EXT_DIR}/${ICE_CFG} ~/.ice/ice-cfg.ini
    debugme cat ~/.ice/ice-cfg.ini
    debugme echo "config.json:"
    debugme cat /home/jenkins/.cf/config.json | cut -c1-2
    debugme cat /home/jenkins/.cf/config.json | cut -c3-
    debugme echo "testing ice login via ice info command"
    ice --verbose info > info.log 2> /dev/null
    RESULT=$?
    debugme cat info.log 
    if [ $RESULT -eq 0 ]; then
        echo "ice info was successful.  Checking login to registry server" 
        ice images &> /dev/null
        RESULT=$? 
    else 
        echo "ice info did not return successfully.  Login failed."
    fi 
fi 

# check login result 
if [ $RESULT -eq 1 ]; then
    echo -e "${red}Failed to login to IBM Container Service${no_color}"
    ice namespace get 2> /dev/null
    HAS_NAMESPACE=$?
    if [ $HAS_NAMESPACE -eq 1 ]; then 
        printEnablementInfo        
    fi
    ${EXT_DIR}/print_help.sh
    exit $RESULT
else 
    echo -e "${green}Successfully logged into IBM Container Service${no_color}"
    ice info 2> /dev/null
fi 

########################
# Setup git_retry      #
########################
source ${EXT_DIR}/git_util.sh

################################
# get the extensions utilities #
################################
pushd . >/dev/null
cd $EXT_DIR 
git_retry clone https://github.com/Osthanes/utilities.git utilities
popd >/dev/null

############################
# enable logging to logmet #
############################
source $EXT_DIR/utilities/logging_utils.sh
setup_met_logging "${BLUEMIX_USER}" "${BLUEMIX_PASSWORD}" "${BLUEMIX_SPACE}" "${BLUEMIX_ORG}" "${BLUEMIX_TARGET}"

##################################
# check environment properties   #
##################################

log_and_echo "Checking environment variables"
if [ -z "$EMAIL" ] && [ -z "$TXT" ] && [ -z "$PHONE" ]; then 
    echo -e "${red}In order to send a notification, you need to provide a Phone Number, Text Number or Email Address" | tee -a "$ERROR_LOG_FILE"
    echo -e "${red}Please set Phone Number, Text Number or Email Address in the environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

if [ -z "$USER_ID" ] || [ -z "$PASSWORD" ]; then 
    echo -e "${red}In order to send a notification, you need to provide a USER_ID and PASSWORD" | tee -a "$ERROR_LOG_FILE"
    echo -e "${red}Please set 'USER_ID' as a Text Property and 'PASSWORD' as a Secure Property in the environment properties ${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

#############################
# Install node, and Mocha   #
#############################
#change directory to /notifications
cd ${EXT_DIR}
# install npm:
log_and_echo "Installing npm"
log_and_echo "apt-get install npm"
sudo apt-get install -y npm 
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install npm"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi  

# install node
log_and_echo "Installing nodejs"
log_and_echo "sudo apt-get install nodejs-legacy"
sudo apt-get install -y nodejs-legacy
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install nodejs"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi 

# install mocha:
log_and_echo "Installing mocha"
log_and_echo "npm install -g mocha"
npm install -g mocha &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install mocha"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi 
# set mocha in env:
node node_modules/.bin/mocha &> /dev/null

# install node modules request and btoa
log_and_echo "Installing node modules"
npm install btoa &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install node modules/btoa"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi 

npm install request &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install node modules/request"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi 

npm install nconf &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install node modules/nconf"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi 

log_and_echo "$LABEL" "Initialization complete"


