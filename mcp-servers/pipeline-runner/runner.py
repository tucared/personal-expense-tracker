#!/usr/bin/env python3
"""Pipeline Runner MCP Server.

Simple MCP server that runs expense tracker pipelines for testing during development.
Provides a single-pipeline constraint with three core operations.
"""

import os
import select
import signal
import subprocess
import sys
import time
from typing import Any, Optional

import httpx
from fastmcp import FastMCP

# Global state
current_pipeline: Optional[str] = None
current_process: Optional[subprocess.Popen[str]] = None

# Configuration
VALID_SERVICES = ["notion", "gsheets"]
VALID_ENVS = ["dev", "prod"]
PIPELINE_PORT = 8080
STARTUP_TIMEOUT = 10


def cleanup_process() -> None:
    """Clean up any running process."""
    global current_pipeline, current_process

    if current_process and current_process.poll() is None:
        try:
            current_process.terminate()
            current_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            current_process.kill()
            current_process.wait()
        except Exception:
            pass  # Process already dead

    current_pipeline = None
    current_process = None


def signal_handler(signum: int, frame: Any) -> None:
    """Handle shutdown signals."""
    cleanup_process()
    sys.exit(0)


# Set up signal handlers
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def validate_service(service: str) -> Optional[str]:
    """Validate service name."""
    if service not in VALID_SERVICES:
        return f"❌ Invalid service. Use: {', '.join(VALID_SERVICES)}"
    return None


def validate_env(env: str) -> Optional[str]:
    """Validate environment."""
    if env not in VALID_ENVS:
        return f"❌ Invalid environment. Use: {', '.join(VALID_ENVS)}"
    return None


def check_makefile() -> Optional[str]:
    """Check if Makefile exists in current directory."""
    if not os.path.exists("Makefile"):
        return "❌ Makefile not found. Run from project root directory."
    return None


def wait_for_startup(process: subprocess.Popen[str], service: str, env: str) -> str:
    """Wait for process to start and listen on port."""
    start_time = time.time()

    while time.time() - start_time < STARTUP_TIMEOUT:
        # Check if process exited early
        if process.poll() is not None:
            stdout_content = ""
            if process.stdout:
                try:
                    stdout_content = process.stdout.read()
                except Exception:
                    pass
            return f"❌ {service}-{env} process exited early. Output: {stdout_content[:200]}"

        # Check for startup message in stdout
        if process.stdout:
            try:
                ready, _, _ = select.select([process.stdout], [], [], 0.1)
                if ready:
                    line = process.stdout.readline()
                    if line and "Running on http://" in line:
                        return f"✅ {service}-{env} started successfully on port {PIPELINE_PORT}"
            except Exception:
                pass  # Continue waiting

        time.sleep(0.1)

    # Timeout - kill the process
    process.terminate()
    return f"❌ {service}-{env} failed to start within {STARTUP_TIMEOUT} seconds"


# Initialize MCP server
mcp = FastMCP("Pipeline Runner")


def _start_pipeline_impl(service: str, env: str = "dev") -> str:
    """Core implementation for starting a pipeline service."""
    global current_pipeline, current_process

    # Validate inputs
    if error := validate_service(service):
        return error
    if error := validate_env(env):
        return error
    if error := check_makefile():
        return error

    # Check if pipeline already running
    if current_pipeline:
        return f"❌ {current_pipeline} is running. Stop it first with stop_pipeline()."

    # Start the pipeline process
    make_target = f"run-{service}-{env}"
    env_vars = os.environ.copy()
    env_vars["PORT"] = str(PIPELINE_PORT)

    try:
        process = subprocess.Popen(
            ["make", make_target],
            env=env_vars,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True,
        )

        # Wait for startup
        result = wait_for_startup(process, service, env)

        if result.startswith("✅"):
            current_pipeline = f"{service}-{env}"
            current_process = process
            return result
        else:
            # Startup failed, clean up
            if process.poll() is None:
                process.terminate()
            return result

    except Exception as e:
        return f"❌ Failed to start {service}-{env}: {str(e)}"


@mcp.tool()
def start_pipeline(service: str, env: str = "dev") -> str:
    """Start a pipeline service.

    Args:
        service: Service name (notion, gsheets)
        env: Environment (dev, prod)

    Returns:
        Status message
    """
    return _start_pipeline_impl(service, env)


def _trigger_pipeline_impl() -> str:
    """Core implementation for triggering the currently running pipeline."""
    if not current_pipeline:
        return "❌ No pipeline running. Start one first with start_pipeline()."

    try:
        with httpx.Client(timeout=30.0) as client:
            response = client.post(f"http://localhost:{PIPELINE_PORT}")

        if response.status_code == 200:
            # Truncate response for readability
            response_text = response.text[:200]
            if len(response.text) > 200:
                response_text += "..."
            return f"✅ Pipeline triggered successfully: {response_text}"
        else:
            return f"❌ Pipeline trigger failed: HTTP {response.status_code} - {response.text[:100]}"

    except httpx.RequestError as e:
        return f"❌ Failed to connect to pipeline: {str(e)}"
    except Exception as e:
        return f"❌ Unexpected error: {str(e)}"


@mcp.tool()
def trigger_pipeline() -> str:
    """Trigger the currently running pipeline.

    Returns:
        Status message with response
    """
    return _trigger_pipeline_impl()


def _stop_pipeline_impl() -> str:
    """Core implementation for stopping the currently running pipeline."""
    global current_pipeline, current_process

    if not current_pipeline:
        return "❌ No pipeline running."

    pipeline_name = current_pipeline
    cleanup_process()
    return f"✅ Stopped {pipeline_name}"


@mcp.tool()
def stop_pipeline() -> str:
    """Stop the currently running pipeline.

    Returns:
        Status message
    """
    return _stop_pipeline_impl()


@mcp.tool()
def run_pipeline(service: str, env: str = "dev") -> str:
    """Run a complete pipeline cycle: start → trigger → stop.

    Args:
        service: Service name (notion, gsheets)
        env: Environment (dev, prod)

    Returns:
        Status message with all operation results
    """
    results = []

    # Start pipeline
    start_result = _start_pipeline_impl(service, env)
    results.append(f"Start: {start_result}")

    if not start_result.startswith("✅"):
        return "\n".join(results)

    # Small delay to ensure pipeline is ready
    time.sleep(0.5)

    # Trigger pipeline
    trigger_result = _trigger_pipeline_impl()
    results.append(f"Trigger: {trigger_result}")

    # Stop pipeline
    stop_result = _stop_pipeline_impl()
    results.append(f"Stop: {stop_result}")

    return "\n".join(results)


@mcp.tool()
def get_status() -> str:
    """Get current pipeline runner status.

    Returns:
        Current status information
    """
    if current_pipeline:
        # Check if process is still alive
        if current_process and current_process.poll() is None:
            return f"✅ Running: {current_pipeline} (port {PIPELINE_PORT})"
        else:
            # Process died, clean up state
            cleanup_process()
            return "❌ Pipeline process died unexpectedly"
    else:
        return "⭕ No pipeline running"


def main() -> None:
    """Main entry point for the MCP server."""
    # Clean up any existing processes on startup
    cleanup_process()

    # Run the MCP server
    mcp.run()


if __name__ == "__main__":
    main()
