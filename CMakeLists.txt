cmake_minimum_required(VERSION 3.19)

project(HertzAIChat)

# ============================================================
# This file configures native builds for the Flutter app
# ============================================================

# Include native subdirectories
add_subdirectory(android/cpp)

message(STATUS "HertzAIChat Native Build Configured")
