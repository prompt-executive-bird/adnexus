#!/bin/bash

##
## new_session.sh - Creates and initialises session files
##
#
# Usage: new_session.sh [identifier] [return email] [number of cards]
#

IDENTIFIER="${1:-}"
RETURN_ADDRESS="${2:-}"
NUMBER_CARDS="${3:-}"

# If not provided via parameters, ask for the following information:
#   - Identifier
#   - Email return address

# Get the identifier, repeating if it was blank
while [ -z "$IDENTIFIER" ]; do
    read -p "Enter a session identifier: " IDENTIFIER
done
# Get the email address, as above
while [ -z "$RETURN_ADDRESS" ]; do
    read -p "Enter a return address for outgoing emails: " RETURN_ADDRESS
done
# Get the default number of cards
while [ -z "$NUMBER_CARDS" ]; do
    read -p "Enter the number of cards to be generated: " NUMBER_CARDS
done

# Change directory to that of this script
cd "$(dirname "$0")"

# Copy the session files to a directory named as the identifier. Return 1 if it
# already exists.
if [ -e "$IDENTIFIER" ]; then
    echo "Error: $0: $IDENTIFIER already exists." >&2
    exit 1
fi

cp -r "skeleton" "$IDENTIFIER"

# Add a symbolic link to the scripts/binaries to the session directory
ln -s "../bin" "$IDENTIFIER/bin"

# Enter into the session directory
cd "$IDENTIFIER"

# Change the pagination in cards/stamped/proper_pagination.tex to match the
# number of cards generated specified previously.
#
# The pagination of stamped.pdf alternates between odd and even subpages in sets
# of two, each set occupying one page. The order reverses on the even side to
# account for the topology of two-sided paper. Hence, it goes
#   (1,3), (4,2), (5,7), ... , (j,j+2), (j+3,j+1), ... .
# This sequence will be generated and inserted into proper_pagination.tex
#
# NB! If n cards are requested, stamped.pdf will contain 2n pages -- 2 for each
#     side of a card.
# NB! The number of cards requested must be even for this to work. Otherwise,
#     n-1 cards will be assembled instead.
#

# Odd numbers will leave a gap in the pagination, so round down to the nearest
# acceptable integer.
if [ $(($NUMBER_CARDS % 2)) -eq 1 ]; then
    NUMBER_CARDS="$(($NUMBER_CARDS - 1))"
fi

# Compute the subpage ordering, pruning the superfluous ',' at the start.
PAGINATION_ORDER=""
for (( j = 1 ; j < (2 * $NUMBER_CARDS); j = $j + 4 )); do
    PAGINATION_ORDER="$PAGINATION_ORDER,$j,$(($j+2)),$(($j+3)),$(($j+1))"
done
PAGINATION_ORDER=${PAGINATION_ORDER:1}

# Place the order in proper_pagination.tex
cat card/stamped/proper_pagination.tex |
    sed -e "s/pages={}/pages={$PAGINATION_ORDER}/" \
> card/stamped/proper_pagination.tex.new
mv card/stamped/proper_pagination.tex.new card/stamped/proper_pagination.tex

# Update SESSION, RETURN_ADDRESS, and NUMBER_CARDS variables in Makefile
cat Makefile |
    sed -e "s/^SESSION =.*$/SESSION = \"$IDENTIFIER\"/" \
        -e "s/^RETURN_ADDRESS =.*$/RETURN_ADDRESS = \"$RETURN_ADDRESS\"/" \
        -e "s/^NUMBER_CARDS =.*$/NUMBER_CARDS = $NUMBER_CARDS/" \
> Makefile.new
mv Makefile.new Makefile

# Update the match card TeX file with appropriate border image.
#
# NB! This directory must be specified as an absolute path, with slashes
#     properly escaped.
BORDER_PATH="$(echo "$(pwd)/card/images/match-card-border.png" |
    sed -e 's/\//\\\//g')"
cat card/match_card.tex |
    sed -e "s/\(\\\newcommand{\\\borderimagepath}\).*/\1{$BORDER_PATH}/" \
    > card/match_card.tex.new
mv card/match_card.tex.new card/match_card.tex

exit 0

