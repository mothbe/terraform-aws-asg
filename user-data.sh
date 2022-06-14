#!/bin/bash
sudo yum install -y httpd
sudo sed -i 's/Listen 80/Listen 31555/' /etc/httpd/conf/httpd.conf
sudo systemctl enable --now httpd
