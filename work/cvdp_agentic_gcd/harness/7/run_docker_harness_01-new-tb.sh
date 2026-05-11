#!/bin/bash

# Auto-generated script to run harness Docker container
# Usage: run_docker_harness_01-new-tb.sh [-d] (where -d enables debug mode with bash entrypoint)
set -e

# Parse command line arguments
DEBUG_MODE=false
while getopts 'd' flag; do
  case "${flag}" in
    d) DEBUG_MODE=true ;;
  esac
done

# Use shared bridge network: cvdp-bridge-cvdp_v1-1-0_agentic_code_generation_no_commercial-64
NETWORK_CREATED=0

# Check if network exists, create if needed
if ! docker network inspect cvdp-bridge-cvdp_v1-1-0_agentic_code_generation_no_commercial-64 &>/dev/null; then
  echo "Creating Docker network cvdp-bridge-cvdp_v1-1-0_agentic_code_generation_no_commercial-64..."
  docker network create --driver bridge cvdp-bridge-cvdp_v1-1-0_agentic_code_generation_no_commercial-64
  NETWORK_CREATED=1
fi

# Function to clean up resources
cleanup() {
  echo "Cleaning up Docker resources..."
  docker compose -f /Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/docker-compose.yml -p cvdp_agentic_gcd_7_1777959929 kill 01-new-tb 2>/dev/null || true
  docker rmi cvdp_agentic_gcd_7_1777959929-01-new-tb 2>/dev/null || true
  if [ $NETWORK_CREATED -eq 1 ]; then
    echo "Removing Docker network cvdp-bridge-cvdp_v1-1-0_agentic_code_generation_no_commercial-64..."
    docker network rm cvdp-bridge-cvdp_v1-1-0_agentic_code_generation_no_commercial-64 2>/dev/null || true
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Run the harness container
echo "Running harness with project name: cvdp_agentic_gcd_7_1777959929"
# Get current user and group IDs
USER_ID=$(id -u)
GROUP_ID=$(id -g)

if [ "$DEBUG_MODE" = true ]; then
  echo "DEBUG MODE: Starting container with bash entrypoint"
  docker compose -f /Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/docker-compose.yml -p cvdp_agentic_gcd_7_1777959929 run --rm --user $USER_ID:$GROUP_ID -e HOME=/code/rundir --entrypoint bash -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/docs:/code/docs" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/rundir:/code/rundir" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/rtl:/code/rtl" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/verif:/code/verif" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/src:/code/src" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/src/llm_lib:/pysubj" --rm -w /code/rundir 01-new-tb
else
  docker compose -f /Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/docker-compose.yml -p cvdp_agentic_gcd_7_1777959929 run --rm --user $USER_ID:$GROUP_ID -e HOME=/code/rundir -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/docs:/code/docs" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/rundir:/code/rundir" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/rtl:/code/rtl" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/verif:/code/verif" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/work/cvdp_agentic_gcd/harness/7/src:/code/src" -v "/Users/siddharth/Documents/chip_agents/nvidia_updated_version/cvdp_benchmark/src/llm_lib:/pysubj" --rm -w /code/rundir 01-new-tb
fi
exit_code=$?

# Exit with the same code as the docker command
exit $exit_code
