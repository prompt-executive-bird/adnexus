#!/bin/bash

##
## idtoname.sh - Retrieves a name from the session database matching a given ID
##
#  Usage: idtoname.sh <id>
#  Returns: (0) Name of participant (stdout)
#           (1) On missing parameter or empty query results
#

# Make sure the parameter was supplied
if [ -z $1 ]; then
    echo "Usage: $0 <id>" >&2
    exit 1
fi

# Change working directory to that of this script
cd "$(dirname $(readlink -f "$0"))"

#
# Session and database information
#
SESSION="19700101-0000"
SESSION_PATH="../.."
DATABASE="$SESSION_PATH/matching/matching.sqlite3"
PERSON="$1"

#
# Database query
#
# Pull the name information from the database, alongside the COUNT of such
# names. The COUNT should be 1, indicating an error otherwise.
#
# COUNT should never be more than 1 as the id column is UNIQUE, but the query
# will only contain 1 line in the presence of the aggregator, regardless.
#
QUERY_RESULT="$(sqlite3 "$DATABASE" "
    SELECT COUNT(name),name FROM contact
    WHERE id = \"$PERSON\";")"
QUERY_COUNT="$(echo $QUERY_RESULT | sed -e 's/^\(.*\)|\(.*\)$/\1/')"
QUERY_NAME="$(echo $QUERY_RESULT | sed -e 's/^\(.*\)|\(.*\)$/\2/')"

# Check that a name was obtained; if not, exit 1
if [ "$QUERY_COUNT" -ne 1 ]; then
    exit 1
else
    echo $QUERY_NAME
fi

exit 0

