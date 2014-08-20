#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}
mkdir -p ../bin/
sudo apt-get install -y python-virtualenv python-pip curl

if [ ! -e "../bin/isapi_venv/bin/pip" ]; then
    echo "installing virtualenv and pip for isapi_venv"
    virtualenv ../bin/isapi_venv
    cd ../bin/isapi_venv
    curl -O http://peak.telecommunity.com/dist/ez_setup.py
    bin/python ez_setup.py
    bin/easy_install pip
    cd ${DIR}
else
    echo "not reinstalling virtualenv and pip for isapi_venv"
fi


../bin/isapi_venv/bin/pip install -r requirements.txt




