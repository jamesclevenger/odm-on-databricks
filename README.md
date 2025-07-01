# odm-on-databricks
Docker file that has ODM [Open Drone Map] and required libraries to run as a single node cluster in Databricks

To use: 
1) clone github.com/OpenDroneMap/ODM
2) replace the Dockerfile with the one in this repo
3) Build a docker image, upload the image to an image repository
4) Enable container services in your Databricks workspace
5) Create a new Compute cluster [I used single node 32gb with 13.3-LTS runtime]
6) Copy source image data into the cluster
7) Run the ODM software using `/code/run.sh /path-to-image-data`

Notes:
GPU acceleration not supported.  Aukerman test data from https://github.com/OpenDroneMap/odm_data_aukerman/tree/master ran in 43 minutes on a single node cluster w 32gb.
