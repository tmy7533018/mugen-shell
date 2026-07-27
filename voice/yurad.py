#!/usr/bin/env python3
"""Yura voice daemon entry point.

Run from a terminal inside the graphical session so `qs ipc` reaches the shell.
The pipeline itself lives in the yura/ package.
"""

from yura.daemon import main

if __name__ == "__main__":
    main()
