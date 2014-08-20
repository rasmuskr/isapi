#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd ${DIR}

../bin/datacollectors_venv/bin/python earthquake/earthquake.py

