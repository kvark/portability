VULKAN_DIR=modules/vulkan-docs/src
CTS_DIR=../VK-GL-CTS
BINDING=target/vulkan.rs
NATIVE_DIR=target/native
TARGET=$(NATIVE_DIR)/test
OBJECTS=$(NATIVE_DIR)/test.o $(NATIVE_DIR)/window.o
LIB_EXTENSION=
TEST_LIST=conformance/deqp.txt
TEST_LIST_SOURCE=$(CTS_DIR)/external/vulkancts/mustpass/1.0.2/vk-default.txt
DEQP=$(CTS_DIR)/build/external/vulkancts/modules/vulkan/deqp-vk

RUST_BACKTRACE:=1
BACKEND:=gl
DEBUGGER=rust-gdb --args

CC=g++
CFLAGS=-std=c++11 -ggdb -O0 -I$(VULKAN_DIR)
DEPS=
LDFLAGS=

ifeq ($(OS),Windows_NT)
	LDFLAGS=
	BACKEND=dx12
	LIB_EXTENSION=dll
else
	UNAME_S:=$(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		LDFLAGS=-lpthread -ldl -lm -lX11 -lxcb
		BACKEND=vulkan
		LIB_EXTENSION=so
	endif
	ifeq ($(UNAME_S),Darwin)
		LDFLAGS=-lpthread -ldl -lm
		BACKEND=metal
		DEBUGGER=rust-lldb --
		LIB_EXTENSION=dylib
	endif
endif

FULL_LIBRARY_PATH=$(CURDIR)/target/debug
LIBRARY=target/debug/libportability.$(LIB_EXTENSION)
LIBRARY_FAST=target/release/libportability.$(LIB_EXTENSION)

.PHONY: all release binding run cts cts-pick cts-debug clean

all: $(TARGET)

release: $(LIBRARY_FAST)

binding: $(BINDING)

$(BINDING): $(VULKAN_DIR)/vulkan/*.h
	bindgen --no-layout-tests --rustfmt-bindings $(VULKAN_DIR)/vulkan/vulkan.h -o $(BINDING)

$(LIBRARY): libportability*/src/*.rs libportability*/Cargo.toml Cargo.lock
	cargo build --manifest-path libportability/Cargo.toml --features $(BACKEND)
	cargo build --manifest-path libportability-icd/Cargo.toml --features $(BACKEND)
	mkdir -p target/native

$(LIBRARY_FAST):  libportability*/src/*.rs libportability*/Cargo.toml Cargo.lock
	cargo build --release --manifest-path libportability/Cargo.toml --features $(BACKEND)
	cargo build --release --manifest-path libportability-icd/Cargo.toml --features $(BACKEND)

$(NATIVE_DIR)/%.o: native/%.cpp $(DEPS) Makefile
	$(CC) -c -o $@ $< $(CFLAGS)

$(TARGET): $(LIBRARY) $(OBJECTS) Makefile
	$(CC) -o $(TARGET) $(OBJECTS) $(LIBRARY) $(LDFLAGS)

run: $(TARGET)
	$(TARGET)

$(TEST_LIST): $(TEST_LIST_SOURCE)
	cat $(TEST_LIST_SOURCE) | grep -v -e ".event" -e "query" >$(TEST_LIST)

cts: $(TARGET) $(TEST_LIST)
	-LD_LIBRARY_PATH=$(FULL_LIBRARY_PATH) $(DEQP) --deqp-caselist-file=$(TEST_LIST)
	python $(CTS_DIR)/scripts/log/log_to_xml.py TestResults.qpa conformance/last.xml
	mv TestResults.qpa conformance/last.qpa
	firefox conformance/last.xml

cts-pick: $(TARGET)
	-LD_LIBRARY_PATH=$(FULL_LIBRARY_PATH) $(DEQP) -n $(name)

cts-debug: $(TARGET)
	LD_LIBRARY_PATH=$(FULL_LIBRARY_PATH) $(DEBUGGER) $(DEQP) -n $(name)

clean:
	rm -f $(OBJECTS) $(TARGET) $(BINDING)
	cargo clean
