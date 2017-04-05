# dockerforlizardz/openswif:jessie - Raspbian Jessie image with Opencv3
# Ryan Drew, 2017
#https://www.theimpossiblecode.com/blog/build-faster-opencv-raspberry-pi3/
#https://www.theimpossiblecode.com/blog/intel-tbb-on-raspberry-pi/
#https://medium.com/@manuganji/installation-of-opencv-numpy-scipy-inside-a-virtualenv-bf4d82220313#.6g3d14mko
#https://forums.resin.io/t/precompiled-python-wheels-for-arm/591
#http://www.pyimagesearch.com/2016/04/18/install-guide-raspberry-pi-3-raspbian-jessie-opencv-3/

FROM resin/rpi-raspbian:jessie

# Change shell to bash and create opencv user
SHELL ["/bin/bash", "--login", "-c"]
RUN adduser --disabled-password --gecos "" cvclient && \
    echo "cvclient ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    touch /home/cvclient/.bashrc
USER cvclient
WORKDIR /home/cvclient

# Install dependencies
RUN sudo apt-get update && \
	sudo apt-get install -y --no-install-recommends \
        apt-utils \
		build-essential \
		checkinstall \
		cmake \
		curl \
		gfortran \
		libatlas-base-dev \
		libavcodec-dev \
		libavformat-dev \
		libgtk2.0-dev \
		libjpeg-dev \
		libpng12-dev \
		libswscale-dev \
		libtiff5-dev \
		libv4l-dev \
		libxvidcore-dev \
		libx264-dev \
		pkg-config \
		python3-pip \
        python3-dev \
        tar \
		unzip && \
    sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*

# Create virtual environment
ENV WORKON_HOME=/home/cvclient/.virtualenvs
ENV VIRTUALENVWRAPPER_VIRTUALENV=/usr/local/bin/virtualenv
ENV VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3.4
RUN sudo pip3 install \
		virtualenv \
		virtualenvwrapper && \
	sudo rm -rf /home/cvclient/.cache/pip && \
	cd /home/cvclient && \
    echo 'source /usr/local/bin/virtualenvwrapper.sh' >> .profile && \
	source .profile && \
	mkvirtualenv opencv3 -p python3 && \
    echo 'workon opencv3' >> .profile

# Install TBB
RUN curl -o tbb44_20160526oss_src_0.tgz \
		https://www.threadingbuildingblocks.org/sites/default/files/software_releases/source/tbb44_20160526oss_src_0.tgz && \
	tar xvf tbb44_20160526oss_src_0.tgz && \
	rm tbb44_20160526oss_src_0.tgz && \
	cd tbb44_20160526oss && \
	make tbb CXXFLAGS="-DTBB_USE_GCC_BUILTINS=1 -D__TBB_64BIT_ATOMICS=0" && \
	cd .. && \
	mkdir libtbb-dev_4.5-1_armhf && \
	cd libtbb-dev_4.5-1_armhf && \
	mkdir -p usr/local/lib/pkgconfig && \
	mkdir -p usr/local/include && \
	mkdir DEBIAN && \
	cd DEBIAN && \
	printf "Package: libtbb-dev\nPriority: extra\nSection: universe/libdevel\nArchitecture: armhf\nVersion: 4.5-1\nHomepage: http://threadingbuildingblocks.org/\nDescription: parallelism library for C++ - development files. This package includes the TBB headers, libs and pkg-config\n" > control && \
	cd ../usr/local/lib && \
	cp /home/cvclient/tbb44_20160526oss/build/*_release/libtbb.so.2 . && \
	ln -s libtbb.so.2 libtbb.so && \
	cd /home/cvclient/tbb44_20160526oss/include && \
	cp -r serial tbb /home/cvclient/libtbb-dev_4.5-1_armhf/usr/local/include && \
	cd /home/cvclient/libtbb-dev_4.5-1_armhf/usr/local/lib/pkgconfig && \
	printf "# Manually added pkg-config file for tbb - START\nprefix=/usr/local\nexec_prefix=${prefix}\nlibdir=${exec_prefix}/lib\nincludedir=${prefix}/include\nName: tbb\nDescription: thread building block\nVersion: 4.4.5\nCflags: -I${includedir} -DTBB_USE_GCC_BUILTINS=1 -D__TBB_64BIT_ATOMICS=0\nLibs: -L${libdir} -ltbb\n# Manually added pkg-config file for tbb - END\n" > tbb.pc && \
	cd /home/cvclient && \
	sudo chown -R root:staff libtbb-dev_4.5-1_armhf && \
	sudo dpkg-deb --build libtbb-dev_4.5-1_armhf && \
	sudo dpkg -i libtbb-dev_4.5-1_armhf.deb && \
	sudo ldconfig && \
	sudo rm -r tbb44_20160526oss && \
	sudo rm -r libtbb-dev_4.5-1_armhf

# Install numpy
RUN pip install --no-cache --extra-index-url=https://gergely.imreh.net/wheels numpy

# Download, build and make opencv3
RUN curl -L -o opencv_contrib-3.2.0.zip https://github.com/Itseez/opencv_contrib/archive/3.2.0.zip && \
	unzip opencv_contrib-3.2.0.zip && \
	rm opencv_contrib-3.2.0.zip && \
	curl -L -o opencv-3.2.0.zip https://github.com/Itseez/opencv/archive/3.2.0.zip && \
	unzip opencv-3.2.0.zip && \
	rm opencv-3.2.0.zip && \
	cd opencv-3.2.0 && \
	mkdir build && \
	cd build && \
	cmake -DCMAKE_BUILD_TYPE=RELEASE \
		-DCMAKE_CXX_FLAGS="-DTBB_USE_GCC_BUILTINS=1 -D__TBB_64BIT_ATOMICS=0" \
		-DENABLE_VFPV3=ON \
		-DENABLE_NEON=ON \
		-DBUILD_TESTS=OFF \
		-DWITH_TBB=ONE \
		-DCMAKE_INSTALL_PREFIX=/home/cvclient/.virtualenvs/opencv3/local \
		-DOPENCV_EXTRA_MODULES_PATH=/home/cvclient/opencv_contrib-3.2.0/modules \
        -DPYTHON_EXECUTABLE=/home/cvclient/.virtualenvs/opencv3/bin/python\
        -DPYTHON_PACKAGES_PATH=/home/cvclient/.virtualenvs/opencv3/lib/python3.4/site-packages .. && \
    make -j 4 && \
    sudo make install && \
	sudo ldconfig && \
	cd /home/cvclient && \
	rm -r opencv_contrib-3.2.0 && \
	rm -r opencv-3.2.0 && \
    deactivate

ENTRYPOINT ["/bin/bash", "--login"]
