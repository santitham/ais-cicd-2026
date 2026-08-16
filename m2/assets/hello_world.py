"""hello_world.py — the simplest possible Databricks job target.

Used in Module 2 Lab B as a smoke test for the CLI workflow.
"""
import sys
from datetime import datetime, timezone


def main() -> None:
    print(f"Hello, world! at {datetime.now(timezone.utc).isoformat()}")
    print(f"Python version: {sys.version}")


if __name__ == "__main__":
    main()
