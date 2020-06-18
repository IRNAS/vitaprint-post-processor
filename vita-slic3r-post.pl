##########
# Created by Moritz Walter 2016, GitHub/makertum, under the GNU Affero General Public License, version 3. 
# Modified by Eva (eva AT irnas DOT eu) for use of Slic3r and PlanetCNC
##########


#!/usr/bin/perl -i
use strict;
use warnings;

# Always helpful
use Math::Round;
use POSIX qw[ceil floor];
use List::Util qw[min max];
use constant PI    => 4 * atan2(1, 1);

##########
# SETUP
# all you can do here is setting default values for printing parameters
# since you don't have to do much here, just scroll down to PROCESSING
##########

# printing parameters
my %parameters=();

# printing parameters, default values (if needed)
$parameters{"someParameter"}=0.2;

# gcode inputBuffer
my @inputBuffer=();
my @outputBuffer=();

# Extruder replacement code
my $relative_extrusion=0;
my $extrusion_control=0;
my $extruder_code="A";
my $extruder_code_relative="[#<_a> + ";

##########
# INITIALIZE
# if you want to initialize variables based on printing parameters, do it here, all printing parameters are available in $parameters
##########

sub init{
	#for(my $i=0;$i<$parameters{"extruders"};$i++){
	#}
}

##########
# PROCESSING
# here you can define what you want to do with your G-Code
# Typically, you have $X, $Y, $Z, $E and $F (numeric values) and $thisLine (plain G-Code) available.
# If you activate "verbose G-Code" in Slic3r's output options, you'll also get the verbose comment in $verbose.
##########

sub process_tool_change
{
	my $thisLine=$_[0],	my $T=$_[1], my $verbose=$_[2];
	# add code here or just return $thisLine;
	if($T==0){
		$extruder_code="A";
		$extruder_code_relative="[#<_a> + ";
		my $newLine = "G1 U0 V15\n";
		$thisLine .= $newLine;
	}
	elsif($T==1){
		$extruder_code="B";
		$extruder_code_relative="[#<_b> + ";
		my $newLine = "G1 U15 V0\n";
		$thisLine .= $newLine;
	}
	return $thisLine;
}

##########
# FILTER THE G-CODE
# here the G-code is filtered and the processing routines are called
##########

sub filter_print_gcode
{
	my $thisLine=$_[0];
	if($thisLine=~/^\h*;(.*)\h*/){
		if($thisLine=~/^; control flow on/){
			$extrusion_control=1;
		}
		# ;: lines that only contain comments
		return $thisLine;
	}elsif ($thisLine=~/^T(\d)(\h*;\h*([\h\w_-]*)\h*)?/){
		# T: tool changes
		my $T=$1; # the tool number
		return process_tool_change($thisLine,$T);
	}elsif($thisLine=~/^G[01](\h+X(-?\d*\.?\d+))?(\h+Y(-?\d*\.?\d+))?(\h+Z(-?\d*\.?\d+))?(\h+E(-?\d*\.?\d+))?(\h+F(\d*\.?\d+))?(\h*;\h*([\h\w_-]*)\h*)?/){
		# G0 and G1 moves
		my $E=$8;
		# regular moves and z-moves
		if($E){
			# seen E
			if($relative_extrusion){
				my $myString = $extruder_code . $extruder_code_relative; # Replace extrusion
				$thisLine =~ s/E/$myString/;
				# convert value of extrusion to string
				my $E_value = "$E";
				# Find position of the value in line
				my $E_idx = index($thisLine, $E_value) + length($E_value);
				# Check if extrusion needs to be scaled
				if($extrusion_control){
					substr($thisLine, $E_idx, 0) = " * #<_hw_jogpot>/511]";
				}
				else{
					substr($thisLine, $E_idx, 0) = "]";
				}
			}
			else{
				$thisLine =~ s/E/$extruder_code/;
			}
		}
		return $thisLine;
	}elsif($thisLine=~/^G92(\h+X(-?\d*\.?\d+))?(\h*Y(-?\d*\.?\d+))?(\h+Z(-?\d*\.?\d+))?(\h+E(-?\d*\.?\d+))?(\h*;\h*([\h\w_-]*)\h*)?/){
		# G92: touching of axis
		$thisLine =~ s/E/$extruder_code/;
		return $thisLine;
	}elsif($thisLine=~/^M82(\h*;\h*([\h\w_-]*)\h*)?/){
		# Comment this line
		$thisLine =~ s/M82/; M82/; 
		return $thisLine;
	}elsif($thisLine=~/^M83(\h*;\h*([\h\w_-]*)\h*)?/){
		# Set to relative extrusion
		$relative_extrusion=1;
		$thisLine =~ s/M83/; M83/; 
		return $thisLine;
	}elsif($thisLine=~/^M84(\h*;\h*([\h\w_-]*)\h*)?/){
		# Comment this line
		$thisLine =~ s/M84/; M84/; 
		return $thisLine;
	}else{
		return $thisLine;
	}
}

sub filter_parameters
{
	# collecting parameters from G-code comments
	if($_[0] =~ /^\h*;\h*([\w_-]*)\h*=\h*(\d*\.?\d+)\h*/){
		# all numeric variables are saved as such
		my $key=$1;
		my $value = $2*1.0;
		unless($value==0 && exists $parameters{$key}){
			$parameters{$key}=$value;
		}
	}elsif($_[0] =~ /^\h*;\h*([\h\w_-]*)\h*=\h*(.*)\h*/){
		# all other variables (alphanumeric, arrays, etc) are saved as strings
		my $key=$1;
		my $value = $2;
		$parameters{$key}=$value;
	}
}

sub process_buffer
{
	# applying all modifications to the G-Code
	foreach my $thisLine (@inputBuffer) {
		push(@outputBuffer,filter_print_gcode($thisLine));
	}
}

sub print_buffer
{
	foreach my $outputLine (@outputBuffer) {
		print $outputLine;
	}
}

##########
# MAIN LOOP
##########

# Creating a backup file for windows
if($^O=~/^MSWin/){
	$^I = '.bak';
}

while (my $thisLine=<>) {
	filter_parameters($thisLine);
	push(@inputBuffer,$thisLine);
	if(eof){
		process_buffer();
		init();
		print_buffer();
	}
}
