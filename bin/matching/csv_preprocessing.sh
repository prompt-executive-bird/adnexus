#!/bin/bash

#
##
## csv_preprocess.sh - Makes SDAPS matching data more human-readable
##
#
# Cleans up an SDAPS CSV file by making several simple replacements for added
# clarity.
#

# Usage
#
# Requires the file to be processed as a parameter. Optionally, an output file
# can be specified. If omitted, the input file is overwritten.
if [ -z $1 ]; then
    echo "Usage: $0 <input> [output]" >&2
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-$1}"

# Surreptitious reading and writing does not bode well for a file on the hard
# drive; so, save the file into memory.
#
# cat only provides '$' for end line markers, so change these to a literal '\n'
# so echo can read them.
CSV=$(cat -E "$INPUT")
CSV=$(echo $CSV | sed 's/\$/\\n/g')

# Identification Number
#
# Make the following substitutions to the ID number column names:
#   * 1_1_1_x, -> id_x10_((x-1)),
#   * 1_1_2_x, -> id_x1_((x-1)),
# for x in {1..10}. The comma is included so 1_1_y_1 does not match 1_1_y_10.
for j in {1..10}; do
    CSV=$(echo $CSV | sed "s/1_1_1_$j,/id_x10_$((j-1)),/")
    CSV=$(echo $CSV | sed "s/1_1_2_$j,/id_x1_$((j-1)),/")
done

# Contact Information
#
# Make the following substitutions to the contact information column names:
#   * 2_1_1 -> name
#   * 2_2_1 -> pronouns
#   * 2_3_1 -> email_address
CSV=$(echo $CSV | sed -e "s/2_1_1/name/" \
                      -e "s/2_2_1/pronouns/" \
                      -e "s/2_3_1/email_address/")

# Match Information
#
# Make the following substitutions to the match information column names:
#   * 3_1_x_1 -> match_x_yes
#   * 3_1_x_2 -> match_x_no
# for x in {1..48}.
for x in {1..48}; do
    CSV=$(echo $CSV | sed -e "s/3_1_${x}_1/match_${x}_yes/" \
                          -e "s/3_1_${x}_2/match_${x}_no/")
done

# Put the text into the output file
echo -en $CSV > $OUTPUT

exit 0

