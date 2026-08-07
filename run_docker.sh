docker run --rm --privileged docker.io/multiarch/qemu-user-static --reset -p yes

docker run -it --rm \
	  --privileged \
	    --name openstick-build \
	      -v "$(pwd)":/OpenStick-Builder \
	        -v /dev:/dev \
		  -w /OpenStick-Builder \
		  docker.io/ubuntu:22.04 \
		      /bin/bash
