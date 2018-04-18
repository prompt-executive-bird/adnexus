#!/bin/bash

##
## compose_email.sh - Creates an email containing pleasantries and contact info
##                    for matches for a single participant, given their ID.
##
#  Usage: compose_email.sh <id>
#
# FIXME: Does not change email style if there are, in fact, zero matches.
#

# Check to ensure the parameter was provided
if [ -z $1 ]; then
    echo "Usage: $0 <person id>" >&2
    exit 1
fi

# Set directory to that of this script
cd "$(dirname $(readlink -f "$0"))"

#
# Session information
#
# Metadata concerning this session's identifier and location. Also, the ID of
# the individual in question.
#
SESSION=""
SESSION_PATH="../.."
PERSON="$1"

#
# Email body parts
#
# Below is a list of all pieces for generic emails. Pieces may be interchanged
# or replaced as desired. All files must be in written in markdown.
#
EMAIL_PATH="$SESSION_PATH/email/skeleton"

SALUTATION="Hello,"
SALUTATION_PUNCTUATION='!'
MATCHING_INTRODUCTION="$EMAIL_PATH/matching_introduction.md"
MATCHING_ADDENDUM="$EMAIL_PATH/matching_addendum.md"
MATCHING_NO_MATCHES="$EMAIL_PATH/matching_no_matches.md"
SELF_PROMOTION="$EMAIL_PATH/self_promotion.md"
VALEDICTION="$EMAIL_PATH/valediction.md"

# Adds a survey link to get the participants' feedback. Omits this section if
# commented.
#
# NB!   The actual link must be added in the referenced file.
#
# TODO: Allow the survey link to include a tracking link, varying with each
#       participant.
#
FEEDBACK="$EMAIL_PATH/feedback_request.md"

#
# Database information and calls
#
# The location of the database used to grab personal information and matching
# data is acquired, and the several SQL queries are made from it.
#
# NB! By default, sqlite3 outputs query results on separate lines, with each
#     column separated by '|'.
#
DATABASE="$SESSION_PATH/matching/matching.sqlite3"
NAME="$("$SESSION_PATH"/bin/idtoname "$PERSON")"
EMAIL="$("$SESSION_PATH"/bin/idtoemail "$PERSON")"
MATCHING_DATA="$(sqlite3 "$DATABASE" "
    SELECT name,email FROM contact
    INNER JOIN match
        ON match.id = contact.id
    WHERE mutual_$PERSON = 1;")"

#
# Sewing together the HTML
#
# Before the HTML is tailored, the email address of the recipient is placed on
# the first line as 'TO: "recipient name" <recipient.address@example.org>'.
#
# The email pieces are put together in the following order:
#   1) Salutation
#   2) Matching, introduction
#   3) List of matches (sed is employed to convert from the SQLite default
#      output to Markdown)
#   4) Matching, addendum
#   5) Request for feedback (optional)
#   6) Self-promotion
#   7) Valediction
# If no matches were made, replace parts (2), (3), and (4) with:
#   A) Matching, no matches
#
# A feedback request is included only if $FEEDBACK is not empty.
#
# Each section is piped through `markdown` to obtain the HTML code.
#
# A !DOCTYPE declaration and <html> tags are also added.
#

# Recipient information
printf 'TO: "%s" <%s>\n' "$NAME" "$EMAIL"
# DOCTYPE declaration and <html> tag
printf '<!DOCTYPE html>\n<html>\n'
# Message body
printf '%s %s%s\n' "$SALUTATION" "$NAME" "$SALUTATION_PUNCTUATION" | markdown
if [ -n "$MATCHING_DATA" ]; then
    cat $MATCHING_INTRODUCTION | markdown
    echo "$MATCHING_DATA" |
        sed -e 's/^\(.*\)|\(.*\)$/ \* \1 \&lt;[\2](mailto:\2)\&gt;/' |
        markdown
    cat "$MATCHING_ADDENDUM" | markdown
else
    cat "$MATCHING_NO_MATCHES" | markdown
fi
# Feedback request
if [ -n $FEEDBACK ]; then cat "$FEEDBACK" | markdown; fi
cat "$SELF_PROMOTION" | markdown
cat "$VALEDICTION" | markdown
# Closing </html> tag
printf '</html>\n'

exit 0

