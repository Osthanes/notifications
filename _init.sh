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

#############################
# Install Cloud Foundry CLI #
#############################
pushd . 
echo "Installing Cloud Foundry CLI"
cd $EXT_DIR 
mkdir bin
cd bin
curl --silent -o cf-linux-amd64.tgz -v -L https://cli.run.pivotal.io/stable?release=linux64-binary &>/dev/null 
gunzip cf-linux-amd64.tgz &> /dev/null
tar -xvf cf-linux-amd64.tar  &> /dev/null

cf help &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "Cloud Foundry CLI not already installed, adding CF to PATH"
    export PATH=$PATH:$EXT_DIR/bin
else 
    echo 'Cloud Foundry CLI already available in container.  Latest CLI version available in ${EXT_DIR}/bin'  
fi 

# check that we are logged into cloud foundry correctly
cf spaces 
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo -e "${red}Failed to check cf spaces to confirm login${no_color}"
    exit $RESULT
else 
    echo -e "${green}Successfully logged into IBM Bluemix${no_color}"
fi 
popd 

export container_cf_version=$(cf --version)
export latest_cf_version=$(${EXT_DIR}/bin/cf --version)
echo "Container Cloud Foundry CLI Version: ${container_cf_version}"
echo "Latest Cloud Foundry CLI Version: ${latest_cf_version}"

##########################################
# setup bluemix env information 
##########################################
CF_API=`cf api`
if [ $? -eq 0 ]; then
    # find the bluemix api host
    export BLUEMIX_API_HOST=`echo $CF_API  | awk '{print $3}' | sed '0,/.*\/\//s///'`
    echo $BLUEMIX_API_HOST | grep 'stage1'
    if [ $? -eq 0 ]; then
        # on staging, make sure bm target is set for staging
        export BLUEMIX_TARGET="staging"
    else
        # on prod, make sure bm target is set for prod
        export BLUEMIX_TARGET="prod"
    fi
elif [ -n "$BLUEMIX_TARGET" ]; then
    # cf not setup yet, try manual setup
    if [ "$BLUEMIX_TARGET" == "staging" ]; then 
        echo -e "Targetting staging Bluemix"
        export BLUEMIX_API_HOST="api.stage1.ng.bluemix.net"
    elif [ "$BLUEMIX_TARGET" == "prod" ]; then 
        echo -e "Targetting production Bluemix"
        export BLUEMIX_API_HOST="api.ng.bluemix.net"
    else 
        echo -e "${red}Unknown Bluemix environment specified${no_color}" | tee -a "$ERROR_LOG_FILE"
    fi 
else 
    echo -e "Targetting production Bluemix"
    export BLUEMIX_API_HOST="api.ng.bluemix.net"
fi

##########################
# Check bluemix login    #
##########################
if [ -n "$BLUEMIX_USER" ] || [ ! -f ~/.cf/config.json ]; then
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
if [ -z "$EMAIL" ] && [ -z "$TXT" ] && [ -z "$PHONE" ] && [ -z "$SLACK_CHANNEL" ]; then 
    echo -e "${red}In order to send a notification, you need to provide a Phone Number, Text Number, Email Address or Slack Channel" | tee -a "$ERROR_LOG_FILE"
    echo -e "${red}Please set Phone Number, Text Number, Email Address or Slack Channel in the environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

if [ -z "$MESSAGE" ]; then 
    echo -e "${red}In order to send a notification, you need to provide a notification message" | tee -a "$ERROR_LOG_FILE"
    echo -e "${red}Please set notification message in the environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

if [ -n "$EMAIL" ] || [ -n "$TXT" ] || [ -n "$PHONE" ]; then
    if [ -z "$NOTIFY_ID" ] || [ -z "$NOTIFY_PASSWORD" ]; then 
        echo -e "${red}In order to send a email, phone, or text notification, you need to provide a NOTIFY_ID and NOTIFY_PASSWORD" | tee -a "$ERROR_LOG_FILE"
        echo -e "${red}Please set 'NOTIFY_ID' as a Text Property and 'NOTIFY_PASSWORD' as a Secure Property in the environment properties ${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/print_help.sh
        exit 1
    fi 
fi

if [ -n "$SLACK_CHANNEL" ] && [ -z "$SLACK_WEBHOOK_PATH" ]; then 
    echo -e "${red}In order to send a stack notification, you need to provide a SLACK_WEBHOOK_PATH" | tee -a "$ERROR_LOG_FILE"
    echo -e "${red}Please set 'SLACK_WEBHOOK_PATH' as a Secure Property in the environment properties ${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi

#############################
# Install node, and Mocha   #
#############################
#change directory to /notifications
cd ${EXT_DIR}
log_and_echo "sudo apt-get update -y"
sudo apt-get update -y &> /dev/null
# install npm:
log_and_echo "Installing npm"
log_and_echo "sudo apt-get install npm"
sudo apt-get install -y npm &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    log_and_echo "$ERROR" "Could not install npm"
    ${EXT_DIR}/print_help.sh    
    exit 1
fi  

# install node
log_and_echo "Installing nodejs"
log_and_echo "sudo apt-get install nodejs-legacy"
sudo apt-get install -y nodejs-legacy &> /dev/null
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


