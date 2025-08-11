# Solar capture rate vs orientation

This notebook (`simulations.ipynb`) compares the _value_ and _volume_ of energy produced by fixed-tilt solar panels in Australia, for different orientations.

It uses `polars`, and lots of data (for the final section of the notebook). This can result in running out of memory, which can cause your computer to crash, even with lots of swap. On Linux I use `./run-docker.sh` to run this inside a Docker container with a hard memory limit. So that way if the memory is filled up, your other applications (e.g. Firefox) what be affected. That's all just to produce the second graph. The first graph can run on a normal laptop outsidee of Docker, with reasonable memory requirements (I have 16GB, but 8GB will probably work too.)