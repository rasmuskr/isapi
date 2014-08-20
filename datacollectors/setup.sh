#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}
mkdir -p ../bin/
sudo apt-get install -y python-virtualenv python-pip

if [ ! -e "../bin/datacollectors_venv/bin/pip" ]; then
    echo "installing virtualenv and pip for datacollectors_venv"
    virtualenv ../bin/datacollectors_venv
    cd ../bin/datacollectors_venv
    curl -O http://peak.telecommunity.com/dist/ez_setup.py
    bin/python ez_setup.py
    bin/easy_install pip
    cd ${DIR}
else
    echo "not reinstalling virtualenv and pip for datacollectors_venv"
fi


../bin/datacollectors_venv/bin/pip install -r requirements.txt


cat << EOF > /etc/cron.d/isapi_datacollectors
* *    * * *   root    bash ${DIR}/datacollectors/trigger-collectors.sh
EOF