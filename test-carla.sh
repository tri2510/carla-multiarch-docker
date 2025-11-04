#!/bin/bash
# Quick test with existing CARLA image

docker run -d \
  --name carla-test \
  --runtime=nvidia \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /dev/input:/dev/input:rw \
  -p 2000:2000 \
  -p 2001:2001 \
  carlasim/carla:0.10.0 \
  /bin/bash -c './CarlaUE5.sh -quality-level=Low -ResX=1280 -ResY=720'

echo "CARLA starting... (takes 30-60 seconds)"
echo "Check logs with: docker logs -f carla-test"
