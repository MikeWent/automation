#!/bin/bash
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[1;30m'
WHITE='\033[1;37m'
NC='\033[0m'

INDICATOR=">>"

function ERROR {
    echo -e "${RED}${INDICATOR} $1 ${NC}"
}

function SUCCESS {
    echo -e "${GREEN}${INDICATOR} $1 ${NC}"
}

function INFO {
    echo -e "${BLUE}${INDICATOR} $1 ${NC}"
}
