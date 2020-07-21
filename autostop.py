#     Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#     Licensed under the Apache License, Version 2.0 (the "License").
#     You may not use this file except in compliance with the License.
#     A copy of the License is located at
#
#         https://aws.amazon.com/apache-2-0/
#
#     or in the "license" file accompanying this file. This file is distributed
#     on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#     express or implied. See the License for the specific language governing
#     permissions and limitations under the License.

import requests
from datetime import datetime
import getopt, sys
import urllib3
import boto3
import json
from datetime import datetime

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Usage
usageInfo = """Usage:
This scripts checks if a notebook is idle for X seconds if it does, it'll stop the notebook:
python autostop.py --time <time_in_seconds> [--port <jupyter_port>] [--ignore-connections]
Type "python autostop.py -h" for available options.
"""
# Help info
helpInfo = """-t, --time
    Auto stop time in seconds
-p, --port
    jupyter port
-c --ignore-connections
    Stop notebook once idle, ignore connected users
-h, --help
    Help information
"""

# Read in command-line parameters
idle = True
port = '8443'
ignore_connections = False
try:
    opts, args = getopt.getopt(sys.argv[1:], "ht:p:c", ["help","time=","port=","ignore-connections"])
    if len(opts) == 0:
        raise getopt.GetoptError("No input parameters!")
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print(helpInfo)
            exit(0)
        if opt in ("-t", "--time"):
            time = int(arg)
        if opt in ("-p", "--port"):
            port = str(arg)
        if opt in ("-c", "--ignore-connections"):
            ignore_connections = True
except getopt.GetoptError:
    print(usageInfo)
    exit(1)

# Missing configuration notificationmissingConfiguration = False
missingConfiguration = False
if not time:
    print("Missing '-t' or '--time'")
    missingConfiguration = True
if missingConfiguration:
    exit(2)


def get_notebook_name():
    log_path = '/opt/ml/metadata/resource-metadata.json'
    with open(log_path, 'r') as logs:
        _logs = json.load(logs)
    return _logs['ResourceName']

# This is hitting Jupyter's sessions API: https://github.com/jupyter/jupyter/wiki/Jupyter-Notebook-Server-API#Sessions-API
response = requests.get('https://localhost:'+port+'/api/sessions', verify=False)
data = response.json()
if len(data) > 0:
    for notebook in data:
        # Idleness is defined by Jupyter
        # https://github.com/jupyter/notebook/issues/4634
        if notebook['kernel']['execution_state'] == 'idle':
            notebook_name = notebook['path']
            curr_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            notebook_time = datetime.strptime(notebook['kernel']['last_activity'], "%Y-%m-%dT%H:%M:%S.%fz")
            idle_time=(datetime.now() - notebook_time).total_seconds()
            if not ignore_connections:
                if notebook['kernel']['connections'] == 0:
                    if idle_time < time:
                        idle = False
                else:
                    idle = False
            else:
                if idle_time < time:
                    idle = False
            print("[{}] Notebook <{}> is inactive for <{}> seconds..."
                  .format(curr_time, notebook_name, idle_time, idle, time))
        else:
            idle = False
else:
    client = boto3.client('sagemaker')
    uptime = client.describe_notebook_instance(
        NotebookInstanceName=get_notebook_name()
    )['LastModifiedTime']
    machine_time = uptime.strftime("%Y-%m-%dT%H:%M:%S.%fz")
    idle_time=(datetime.now() - datetime.strptime(machine_time,"%Y-%m-%dT%H:%M:%S.%fz")).total_seconds()
    curr_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print("[{}] The machine is inactive for <{}> seconds...".format(curr_time, idle_time))
    if idle_time < time:
        idle = False

if idle:
     curr_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
     print("\t[{}] SHUTDOWN STARTED - as all notebooks are idle now...".format(curr_time))
     client = boto3.client('sagemaker')
     client.stop_notebook_instance(
         NotebookInstanceName=get_notebook_name()
     )

