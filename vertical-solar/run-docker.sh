#!/bin/bash
set -e
docker build -t jupyter-pl ./
docker run -it --rm \
  --memory=11g \
  --memory-swap=20g \
  -p 8888:8888 \
  -v $(pwd):/laptop \
  -v /home/matthew/Data:/home/matthew/Data/ \
  jupyter-pl
