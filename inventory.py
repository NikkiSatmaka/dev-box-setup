#!/usr/bin/env python3

import json
import platform
import sys

import distro

hostname = platform.uname().node
distribution = distro.id().capitalize()

inventory = {
    "_meta": {"hostvars": {hostname: {"ansible_connection": "local"}}},
    distribution: {
        "hosts": [hostname],
    },
}

try:
    flag = sys.argv[1]
except IndexError:
    flag = None

print(json.dumps(inventory)) if flag == "--list" else print(json.dumps({}))
