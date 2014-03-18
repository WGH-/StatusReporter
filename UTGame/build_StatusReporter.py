#!/usr/bin/env python3

import build

def main():
    build.build(
        mods=["StatusReporter"],
        files_to_hide=[
            "Config/UTStatusReporter.ini",
        ],
        merges=[],
        cooking=["StatusReporter"]
    )
    

if __name__ == "__main__":
    main()
