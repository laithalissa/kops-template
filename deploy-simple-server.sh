#!/bin/bash
helm install --name simple-server ./server/chart -f ./sever/chart/values.yaml
