#!/bin/bash

cd stable-diffusion-webui/
ACCELERATE=true bash ./webui.sh -f --api --listen --port 8080 --xformers --enable-insecure-extension-access