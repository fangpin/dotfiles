OPENCV_PATH=/home/fangpin/Downloads/caffe-dep/opencv-3.1.0


sudo apt-get install build-essential
sudo apt-get install cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev
sudo apt-get install python-dev python-numpy libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libjasper-dev libdc1394-22-dev
cd $OPENCV_PATH
mkdir build
cd build
cmake -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr/local \
-D WITH_IPP=OFF \
PYTHON2_EXECUTABLE = `which python` \
PYTHON_INCLUDE_DIR = /usr/include/python2 \
PYTHON_INCLUDE_DIR2 = /usr/include/x86_64-linux-gnu/python2 \
PYTHON_LIBRARY = /usr/lib/x86_64-linux-gnu/libpython2.so \
PYTHON2_NUMPY_INCLUDE_DIRS = /usr/lib/python2/dist-packages/numpy/core/include/ ..
sudo make -j8 install
