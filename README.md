# vitaprint-postProcessor

This repository contains post-processing algorithms for g-code created in Slic3r software, to use with the Vitaprint platform.

## Usage
1. Directly in Slic3r:
Copy the path to desired post-processor file (e.g. C:\....\vita-slic3r-post.pl) to Slic3r -> Print Settings -> Output options -> Post-processing scripts and export g-code.

2. Using command line (Python scripts)
In command line execute post-processing script with paths to input g-code and output g-code (e.g. python vita-py-post-slic3r.py C:\...\input.gcode C:\...\output.gcode)
