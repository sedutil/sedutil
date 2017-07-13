# Images

## Docker

Docker can be used as a repeatable build environment to build the images in an Ubuntu 16.04 container.  Steps to reproduce from the `images` directory:


### Step 1 - Build the Docker container

    sudo docker build -t sedutil .

### Step 2 - Run the build from within the Docker container

To explore build options, run the Docker container without arguments:

    sudo docker run --rm -it -v $PWD/../:/sedutil --privileged sedutil

For a complete build with US keyboard support, run:

    sudo docker run --rm -it -v $PWD/../:/sedutil --privileged sedutil /sedutil/images/autobuild.sh complete

To rebuild with German keyboard support, run:

    sudo docker run --rm -it -v $PWD/../:/sedutil --privileged sedutil /sedutil/images/autobuild.sh -k qwertz/de-latin1 images dist

Or, refer to `BUILDING` file and run manually in the Docker container by
starting `bash`:

    sudo docker run --rm -it -v $PWD/../:/sedutil --privileged sedutil bash
