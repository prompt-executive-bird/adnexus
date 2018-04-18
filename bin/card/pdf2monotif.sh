#!/bin/bash

#
##
## pdf2monotif - Converts multipage PDFs to multipage, monochrome TIFs
##
#
# Usage: pdf2monotif <input> [output]
#   where input is the PDF to-be-converted and output is the optional converted
#   TIF.
#

if [ -z $1 ]; then
    >&2 echo "Usage: $0 <input> [output]"
    exit 1
fi

# Assign INPUT and OUTPUT using the given parameters. If the output file was not
# supplied, use the input filename with '.pdf' remove (if present) and '.tif'
# added as a suffix.
INPUT="$1"
OUTPUT="${2:-${INPUT%.pdf}.tif}"

# First, break the PDF into its constituent pages, cropped and converted to TIF.
# Pagination is required as `convert' will not handle the conversion properly
# otherwise.
#
# The filename of each page is written by tacking an identifying number to the
# end, before the extension.
#
# The -gravity option specifies where ImageMagick starts to crop the images.
# 'NorthWest' is the default. Set this to wherever the card is in the scan.
#
echo "Breaking $INPUT into its pages ..."
convert -density 300 $INPUT \
        -gravity NorthWest \
        -crop 1275x1650+0+0 +repage \
        ${INPUT%.pdf}%d.tif

# Take each page, and apply the following effects, in order:
#   - sigmoidal-contrast -- Increase contrast so colours are easier to filter
#                           out.
#   - fx "..."           -- Saturation filter; replace coloured (i.e.,
#                           high-saturation and non-low-lightness) pixels with
#                           white.
#   - monochrome         -- Make the image black-and-white
#
# Pages are saved as TIFs in $OUTPUT
#
for f in ${INPUT%.pdf}?*.tif; do
    echo "Converting $f ..."
    convert "$f" \
            -sigmoidal-contrast 5 \
            -fx "(saturation > 0.2) && (lightness > 0.3) ? white : p" \
            -monochrome \
            "$f"
done

# Merge all single TIFs into one, multipage TIF.
printf "Merging %s?*.tif -> %s ...\n" "${INPUT%.pdf}" "$OUTPUT"
convert "${INPUT%.pdf}"?*.tif "$OUTPUT"

# Remove temporary files that have now been merged.
#
# XXX: This ugliness is required to remove the temporary files while not
#      clobbering the thing we just output. There should be a way to make this
#      less arcane... .
rm $( for f in $(dirname $INPUT)/*; do
          printf '%s\n' "$f"
      done | grep "${INPUT%.pdf}[[:digit:]]\+\.tif$" )

exit 0

