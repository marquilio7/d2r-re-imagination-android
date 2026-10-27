APP_ABI := arm64-v8a x86_64

# Min runtime API level: 24 (ifaddrs y bionic estables)
APP_PLATFORM := android-24

# SDL2 usa C++ (hidapi/android/hid.cpp): hace falta la STL compartida
APP_STL := c++_shared
