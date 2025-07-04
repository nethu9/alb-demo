#!/bin/bash

sudo yum update -y
sudo yum install -y httpd git
sudo systemctl start httpd
sudo systemctl enable httpd
echo '<h1>Hello from the Web Layer!</h1>' | sudo tee /var/www/html/index.html