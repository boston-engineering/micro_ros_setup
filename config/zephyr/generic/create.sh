# Reminder: Zephyr recommended dependecies are: git cmake ninja-build gperf ccache dfu-util device-tree-compiler wget python3-pip python3-setuptools python3-tk python3-wheel xz-utils file make gcc gcc-multilib software-properties-common -y

CMAKE_VERSION_NUMBER=$(cmake --version | grep "[0-9]*\.[0-9]*\.[0-9]*" | cut -d ' ' -f 3)
CMAKE_VERSION_MAJOR_NUMBER=$(echo $CMAKE_VERSION_NUMBER | cut -d '.' -f 1)
CMAKE_VERSION_MINOR_NUMBER=$(echo $CMAKE_VERSION_NUMBER | cut -d '.' -f 2)
CMAKE_VERSION_PATCH_NUMBER=$(echo $CMAKE_VERSION_NUMBER | cut -d '.' -f 3)

if ! (( $CMAKE_VERSION_MAJOR_NUMBER > 3 || \
    $CMAKE_VERSION_MAJOR_NUMBER == 3 && $CMAKE_VERSION_MINOR_NUMBER > 13 || \
    $CMAKE_VERSION_MAJOR_NUMBER == 3 && $CMAKE_VERSION_MINOR_NUMBER == 13 && $CMAKE_VERSION_PATCH_NUMBER >= 1 )); then
    echo "Error: installed CMake version must be equal or greater than 3.13.1."
    echo "Your current version is $CMAKE_VERSION_NUMBER."
    echo "Please if not installed follow the instructions: https://docs.zephyrproject.org/latest/getting_started/index.html"
    exit 1
fi

export PATH=~/.local/bin:"$PATH"
# See SDK/RTOS version matrix here: https://docs.google.com/spreadsheets/d/1wzGJLRuR6urTgnDFUqKk7pEB8O6vWu6Sxziw_KROxMA/edit#gid=0
export ZEPHYR_VERSION="0.14.2"
export HOST_ARCH=$(uname -m)

pushd $FW_TARGETDIR >/dev/null

    west init zephyrproject
    pushd zephyrproject >/dev/null
        cd zephyr
          git checkout zephyr-v3.1.0
        cd ..
        west update
    popd >/dev/null

    pip3 install -r zephyrproject/zephyr/scripts/requirements.txt --ignore-installed

    export SDK_VERSION=zephyr-sdk-${ZEPHYR_VERSION}_linux-${HOST_ARCH}.tar.gz

    if [ "$PLATFORM" = "host" ]; then
        export TARGET_TOOLCHAIN=${HOST_ARCH}-zephyr-elf
    else
        # Support for ARM only
        export TARGET_TOOLCHAIN=arm-zephyr-eabi
    fi

    # Get SDK
    wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v$ZEPHYR_VERSION/$SDK_VERSION
    wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v$ZEPHYR_VERSION/sha256.sum | shasum --check --ignore-missing
    
    # Extract sdk
    tar xvf $SDK_VERSION
    # Rename the versioned sdk folder to generic
    mv zephyr-sdk-$ZEPHYR_VERSION zephyr-sdk
    pushd zephyr-sdk >/dev/null
    # Setup with requested target toolchain
    ./setup.sh -h -c -t ${TARGET_TOOLCHAIN}
    popd > /dev/null
    # Cleanup, remove the downloaded tar
    rm -rf $SDK_VERSION

    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=$FW_TARGETDIR/zephyr-sdk

    # Import repos
    vcs import --input $PREFIX/config/$RTOS/generic/board.repos

    # ignore broken packages
    touch mcu_ws/ros2/rcl_logging/rcl_logging_spdlog/COLCON_IGNORE
    touch mcu_ws/ros2/rcl/COLCON_IGNORE
    touch mcu_ws/ros2/rosidl/rosidl_typesupport_introspection_cpp/COLCON_IGNORE
    touch mcu_ws/ros2/rcpputils/COLCON_IGNORE
    touch mcu_ws/uros/rcl/rcl_yaml_param_parser/COLCON_IGNORE
    touch mcu_ws/uros/rclc/rclc_examples/COLCON_IGNORE

    # Workaround. Remove when https://github.com/sphinx-doc/sphinx/issues/10291 and https://github.com/micro-ROS/micro_ros_zephyr_module/runs/5714546662?check_suite_focus=true
    pip3 install --upgrade Sphinx

popd >/dev/null
