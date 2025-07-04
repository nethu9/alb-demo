#!/bin/bash

sudo yum update -y
sudo yum install -y python3 git
pip3 install flask
git clone https://github.com/nethu9/alb-demo.git
cd alb-demo/app
nohup python3 app.py & # & runs the process in the backgroud , nohup - no hang up allows process keeps running even after the terminal ends.