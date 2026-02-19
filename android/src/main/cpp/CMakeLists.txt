cmake_minimum_required(VERSION 3.4.1)
project(native_binder)

add_library(native_binder SHARED native_binder_jni.c)
target_link_libraries(native_binder android log)
