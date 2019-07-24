#!/bin/bash
helm upgrade --install nginx-ingress stable/nginx-ingress -f ./etc/nginx-values.yaml
