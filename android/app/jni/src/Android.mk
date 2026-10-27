LOCAL_PATH := $(call my-dir)

PORT_ROOT := $(LOCAL_PATH)/../port

# Versión del código = commit de git (igual que CMakeLists.txt), para que la red
# solo junte máquinas con la misma versión. Prioridad: variable de entorno que
# setea compilar-android.ps1; si no, git; si no, "dev".
D2_VER := $(D2_GIT_VERSION)
ifeq ($(D2_VER),)
D2_VER := $(shell git -C $(abspath $(PORT_ROOT)) rev-parse --short=12 HEAD 2>/dev/null)
endif
ifeq ($(D2_VER),)
D2_VER := dev
endif

include $(CLEAR_VARS)

LOCAL_MODULE := main

SDL_PATH := ../SDL

LOCAL_C_INCLUDES := $(LOCAL_PATH)/$(SDL_PATH)/include \
                    $(PORT_ROOT)/src \
                    $(PORT_ROOT)/src/fmt

# Flags de determinismo de la red (igual que CMakeLists.txt): ARM junta FMA y
# char es sin signo por defecto; y las funciones de math.h del sistema difieren
# en el ultimo bit, por eso se usan las de src/dmath.h.
LOCAL_CFLAGS := -ffp-contract=off -fsigned-char -Wall -Wextra \
                -DD2_VERSION=\"$(D2_VER)\" \
                -DSCREEN_W=1333 -DSCREEN_H=600

ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
LOCAL_CFLAGS += -fno-tree-slp-vectorize
endif

# Fuentes del motor (src/*.c) y de los lectores de formatos (src/fmt/*.c).
LOCAL_SRC_FILES := \
    $(PORT_ROOT)/src/audio.c \
    $(PORT_ROOT)/src/bot.c \
    $(PORT_ROOT)/src/charanim.c \
    $(PORT_ROOT)/src/cinema.c \
    $(PORT_ROOT)/src/compat.c \
    $(PORT_ROOT)/src/controls.c \
    $(PORT_ROOT)/src/cube.c \
    $(PORT_ROOT)/src/dmath.c \
    $(PORT_ROOT)/src/font.c \
    $(PORT_ROOT)/src/game.c \
    $(PORT_ROOT)/src/input.c \
    $(PORT_ROOT)/src/items.c \
    $(PORT_ROOT)/src/itemstats.c \
    $(PORT_ROOT)/src/jobs.c \
    $(PORT_ROOT)/src/lang.c \
    $(PORT_ROOT)/src/main.c \
    $(PORT_ROOT)/src/map.c \
    $(PORT_ROOT)/src/menu.c \
    $(PORT_ROOT)/src/missiles.c \
    $(PORT_ROOT)/src/net.c \
    $(PORT_ROOT)/src/overlays.c \
    $(PORT_ROOT)/src/sequences.c \
    $(PORT_ROOT)/src/skills.c \
    $(PORT_ROOT)/src/steamui.c \
    $(PORT_ROOT)/src/strings.c \
    $(PORT_ROOT)/src/ui.c \
    $(PORT_ROOT)/src/units.c \
    $(PORT_ROOT)/src/video.c \
    $(PORT_ROOT)/src/world.c \
    $(PORT_ROOT)/src/fmt/animdata.c \
    $(PORT_ROOT)/src/fmt/cof.c \
    $(PORT_ROOT)/src/fmt/dcc.c \
    $(PORT_ROOT)/src/fmt/ds1.c \
    $(PORT_ROOT)/src/fmt/dt1.c \
    $(PORT_ROOT)/src/fmt/flac.c \
    $(PORT_ROOT)/src/fmt/fs.c \
    $(PORT_ROOT)/src/fmt/sprite.c \
    $(PORT_ROOT)/src/fmt/ttf.c \
    $(PORT_ROOT)/src/fmt/txt.c

LOCAL_SHARED_LIBRARIES := SDL2

LOCAL_LDLIBS := -lGLESv1_CM -lGLESv2 -lOpenSLES -llog -landroid -lz -lm

include $(BUILD_SHARED_LIBRARY)
