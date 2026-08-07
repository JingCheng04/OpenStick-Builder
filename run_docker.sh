# x86转arm64 转译
docker run --rm --privileged docker.io/multiarch/qemu-user-static --reset -p yes

# Ubuntu Docker, 为后续需要必须挂载loop路径
docker run -it --rm \
	  --privileged \
	    --name openstick-build \
	      -v "$(pwd)":/OpenStick-Builder \
	        -v /dev:/dev \
		  -w /OpenStick-Builder \
		  docker.io/ubuntu:22.04 \
		      /bin/bash
