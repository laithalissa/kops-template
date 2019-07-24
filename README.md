# K8s cluster creation script on AWS using Kops

This is just for my reference. I've not even executed this script yet, so don't expect it to work

## Getting started
1) Edit config.sh and set all the environment variables to suit your needs
2) Execute set-up-k8s.sh
3) Optionally deploy other services
   I included:
   - A deploy-nginx-ingress-chart.sh for convenience, overrides in etc/nginx-values.yaml
   - A deploy-simple-server.sh to deploy a simple python echo server
