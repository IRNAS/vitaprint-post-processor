#!/usr/bin/python
# -*- coding: utf-8 -*-

#    Copyright 2015 Alexander Roessler (mail AT roessler DOT systems)
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#    https://github.com/machinekoder/Machinekit-Slic3r-postprocess

#####
#
#	Modified by Boštjan (bostjan AT irnas DOT eu) for use of Slic3r and PlanetCNC
#
#   To do:
#   - modifications for multiple extrusion variables
#
#####

'''
Usage:
	a) Use in command line:
	> C:\...\path-to-files-directory pyton inputfile.gcode outputfile.gcode
	
	b) Use with Slic3r:
	Go to Settings -> Print settings -> Output options
	Paste path to postprocessor into the post-processing scripts bracket. For more info see https://manual.slic3r.org/advanced/post-processing
	
	To modify the replacements, change the values in the replacements variable. For more information on regular expressions, see: https://www.dataquest.io/wp-content/uploads/2019/03/python-regular-expressions-cheat-sheet.pdf
	
'''

import os
import sys
import argparse
import re

replacements = [
    [r'(G(?:0|1|2|3|28|92).*)(?:E)([-\+]?[\d\.].*)', r'\1A\2'], # change all Es to As
    [r'(?:A)([+|-]?\d+\.\d+)', r'A[#<_a> +\1]'], # change extrusion to relative values
    [r'\]\n',r']\n'], # dummy variable for flow-control
    [r'G10', r'G22'],
    [r'G11', r'G23'],
    [r'(M(?:104|106|109|140|141|190|191).*)(?:S)([\d\.].*)', r'\1P\2'],
    [r'.*M83.*', '']
]

endCode = 'M2 ; end of program'
endTerm = r'(?:\s*M2.*|\s%.*)'

regMatch = []

def compile_replacements():
    for regexString, replacement in replacements:
        regex = re.compile(regexString, flags=re.IGNORECASE)
        regMatch.append([regex, replacement])

def do_replacements(line):
    for regex, replacement in regMatch:
        line = regex.sub(replacement, line)
    return line

def flowcontrol(fb):
    buffer = fb.read()
    if 'control flow on' in buffer:
        flow = ' * #<_hw_jogpot>/511]\n'
    else:
        flow = ']\n'
    return flow

def main():
    parser = argparse.ArgumentParser(description='This application converts RepRap flavour GCode to Machinekit flavour GCode')
    parser.add_argument('infile', nargs='?', type=argparse.FileType('r+', encoding='UTF-8'), 
                        default=sys.stdin, help='input file, takes input from stdin if not specified')
    parser.add_argument('outfile', nargs='?', type=argparse.FileType('w'), 
                        default=sys.stdout, help='output file, prints output to stdout of not specified')
    parser.add_argument('-d', '--debug', help='enable debug mode', action='store_true')
    args = parser.parse_args()

    hasProgramEnd = False
    inFile = args.infile
    outFile = args.outfile

    f = open(inFile.name,"r+") # make backup variable of inFile
    fb = open(inFile.name,"r") # make another backup of inFile
    flow = flowcontrol(fb) # determine if flow control is on/off
    # print(flow)
    replacements[2][1] = flow # change flow parameter in replacements list

    compile_replacements()
    endRegex = re.compile(endTerm, flags=re.IGNORECASE)

    for line in inFile:
        if outFile.name == '<stdout>': #if there is no output variable, overwrite input variable
            f.truncate(0)
            f.flush()
            outFile = f

        newline = do_replacements(line)
        outFile.write(newline)

        if (not hasProgramEnd) and endRegex.match(newline):  # check for end of program
            hasProgramEnd = True
            
    if not hasProgramEnd:
        outFile.write(endCode + "\n")
	
    inFile.close()
    outFile.close()
	
    exit(0)
    
if __name__ == "__main__":
    main()