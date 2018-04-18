#!/bin/bash

##
## sqlite_refinement.sh - Adds refinements to SDAPS raw CSV data
##
#
# FIXME: This description is outmoded.
#
# Usage: ./sqlite_refinement.sh <database> [table]
#   where database is in sqlite3 format and has a table 'raw' with columns
#   'match_\d+_(yes|no)'.
#

if [ -z $1 ]; then
    echo "Usage: $0 <database> [table]" >&2
    exit 1
fi

DATABASE=$1
TABLE=${2:-match}

#
# get_size - Event size function
#
# Outputs the number of participants that attended to standard output.
#
# NB! There are many places where this function can go wrong, and it is
#     imperative that it does not. Double check that the database/CSV file
#     contains data from all Match Cards.
#
# FIXME: This function simply counts the number of rows with unique id columns.
#        Consider performing more hand-holding, as this may fail under certain
#        circumstances.
#
# Usage: get_size
# Output: Function value is echoed to standard output. Returns nonzero on error.
#
function get_size {
    local SIZE=$(echo "SELECT COUNT(id) FROM $TABLE;" | sqlite3 $DATABASE)
    # In case the SQLite query went wrong
    if [ -z $SIZE ]; then
        return 1;
    fi
    echo $SIZE
    return 0
}

#
# delta - Adjacent seat function
#
# Given the number of participants, person ID, and a generalised card parameter,
# outputs the card parameter of the person sitting adjacent to standard output.
# See docs/speed_meeting_transformation_equations for a detailed explanation.
#
# TODO: Use get_size instead of requiring it be inputted manually.
#
# Usage: delta <number of participants> <person> <card parameter>
# Output: Function value is echoed to standard output. Returns nonzero when
# lacking parameters.
#
function delta {
    # Prepare parameters by giving less arcane names and ensuring their
    # existence.
    local SIZE=$1
    local PERSON=$2
    local CARD_PARAM=$3
    if [[ ( -z $SIZE ) || ( -z $PERSON ) || ( -z $CARD_PARAM ) ]]; then
        return 1
    fi

    if   [[ $PERSON -eq 0 ]]; then
        echo $(($SIZE - 1))
    elif [[ $CARD_PARAM -eq $(($SIZE - 1)) ]]; then
        echo $(($SIZE - $PERSON))
    else
        echo $(( ($SIZE - 1) - $CARD_PARAM))
    fi
    return 0
}

#
# rho - The partnering function
#
# Given the number of participants, a person id, and card parameter, returns
# the id of the person sitting across from them. See doc/
# speed_meeting_transformation_equations.pdf for more details.
#
# TODO: Use get_size instead of requiring it be inputted manually.
#
# Usage: rho <number of participants> <person id> <card parameter>
# Domain restrictions: (n > 0 and even), (0 < p <= n-1), (0 < s <= n-1)
# Output: Function value is echoed to standard output. Returns nonzero when
# lacking parameters or on domain errors.
function rho {
    # Prepare the parameters for use by:
    #   - Giving them descriptive names
    #   - Checking existence of their values
    #   - Checking that the domain is observed
    # Return 1 if either of the checks fails.
    local SIZE=$1
    local PERSON=$2
    local CARD_PARAM=$3
    if [[ (-z $SIZE) || (-z $PERSON) || (-z $CARD_PARAM) ]]; then
        return 1
    fi
    if ! [[ ( ( ($SIZE -gt 0) && ($(($SIZE % 2)) -eq 0) )
              && ( ($PERSON -ge 0) && ($PERSON -lt $SIZE) )
              && ( ($CARD_PARAM -gt 0) && ($CARD_PARAM -lt $SIZE) )
            ) ]]; then
        return 1
    fi

    # Evaluate rho as per the piecewise definition in the above-referenced
    # documentation. Output it to standard output and return 0.
    #
    # The value of 2s-p is calculated as $GAMMA for ease of reading.
    #
    local GAMMA=$(( (2*$CARD_PARAM) - $PERSON))
    local RHO=
    if   [ $PERSON -eq 0 ]; then
        RHO=$(( $SIZE - $CARD_PARAM ))
    elif [ $CARD_PARAM -eq $(($SIZE - 1)) ]; then
        RHO=0
    elif [ $GAMMA -lt 0 ]; then
        RHO=$((-$GAMMA))
    elif [ $GAMMA -ge $(($SIZE-1)) ]; then
        RHO=$((2*($SIZE-1) - $GAMMA))
    else # ($GAMMA -ge 0) -a ($GAMMA -lt $(($SIZE-1)) )
        RHO=$(( ($SIZE-1) - $GAMMA))
    fi

    echo $RHO
    return 0
}

# Create the table storing the refined data
sqlite3 $DATABASE "
    CREATE TABLE IF NOT EXISTS $TABLE
    (
        card_id         INTEGER     PRIMARY KEY,
        id              INTEGER     UNIQUE
    );"

# Populate the refined table with all questionnaire_ids in 'raw'
sqlite3 $DATABASE "
    INSERT INTO ${TABLE}(card_id)
    SELECT questionnaire_id FROM raw;"

# Import ID information from raw.
#
# This is done by adding 10 times the sum of all id_x10_[0-9] and the sum of all
# id_x1_[0-9]. This ends up looking a bit arcane, seated in the SELECT query.
#
# The WHERE EXISTS condition at the end prevents UPDATE from changing columns in
# the refined table that do not exist; however, this should never be the case
# and it is included only because it is best praxis.
#
# FIXME: This assumes only one of each id_{x10,x1}_[0-9] are marked. This should
#        be checked beforehand to avoid spurious results.
sqlite3 $DATABASE "
    UPDATE $TABLE
    SET id = (
        SELECT 10 * ( (0 * id_x10_0) + (1 * id_x10_1) + (2 * id_x10_2)
                    + (3 * id_x10_3) + (4 * id_x10_4) + (5 * id_x10_5)
                    + (6 * id_x10_6) + (7 * id_x10_7) + (8 * id_x10_8)
                    + (9 * id_x10_9) )
                  + ( (0 * id_x1_0) + (1 * id_x1_1) + (2 * id_x1_2)
                    + (3 * id_x1_3) + (4 * id_x1_4) + (5 * id_x1_5)
                    + (6 * id_x1_6) + (7 * id_x1_7) + (8 * id_x1_8)
                    + (9 * id_x1_9) )
        FROM raw
        WHERE raw.questionnaire_id = $TABLE.card_id
    )
    WHERE EXISTS (
        SELECT * FROM raw
        WHERE raw.questionnaire_id = $TABLE.card_id
    );"

# Add columns match_{1..48} to TABLE
sqlite3 $DATABASE "ALTER TABLE $TABLE
                   ADD match_"{1..48}" DEFAULT 0;"

# On corresponding rows, for every possible match j, make column match__seat j
# equal to 1 iff both match_j_yes is true and match_j_no is false in 'raw'.
# Checks to ensure that rows in 'refined' also exist in 'raw' are also
# performed.
#
# Hence, the only way one can mark as matching someone else is to fill the 'Y'
# and leave empty the 'N'. All other possibilities are interpreted as a 'N'.
for j in {1..48}; do
    sqlite3 $DATABASE "
        UPDATE $TABLE
        SET match_$j = (
            SELECT raw.match_${j}_yes = 1 AND raw.match_${j}_no = 0
            FROM raw
            WHERE raw.questionnaire_id = $TABLE.card_id )
        WHERE EXISTS (
            SELECT * FROM raw
            WHERE raw.questionnaire_id = $TABLE.card_id );"
done

# Mutual Matching Computation
#
# In 'refined', create columns mutual_x for x = 0 ~ 48 with a
# default value of 0.
#
# For every id = p, and every s = 1 ~ (n-1), calculate rho(p,s). Then,
# mutual_rho(p,s) = 1 iff. match_s = 1 and -- for id =
# rho(p,s) -- match_delta(s) = 1.
#

# Create mutual_* columns
sqlite3 $DATABASE "
    ALTER TABLE $TABLE
    ADD mutual_"{0..48}" DEFAULT 0;"

# For all persons and seats/card parameters, if a match occurred with and there,
# check if the same is true for their interlocutor. If so, set
# mutual_rho to reflect it; otherwise, do nothing.
#
# FIXME: Note that -- as mutual matches are symmetric -- the same computations
#        will be performed twice. To optimize, consider removing this
#        superfluous number crunching.
N=$(get_size)
for (( p = 0 ; p < $N ; ++p )); do
    for (( s = 1 ; s < $N ; ++s )); do
        IS_MATCH=$(echo "SELECT match_$s
                         FROM $TABLE
                         WHERE id = $p;" | sqlite3 $DATABASE)

        if [[ $IS_MATCH -eq 1 ]]; then
            MY_RHO=$(rho $N $p $s)
            MY_DELTA=$(delta $N $p $s)

            # FIXME: The usage of $MY_DELTA below is problematic; it will not
            #        function when $MY_RHO is the odd-person-out.
            IS_MUTUAL_MATCH=$(echo "SELECT match_$MY_DELTA
                                    FROM $TABLE
                                    WHERE id = $MY_RHO;" | sqlite3 $DATABASE)

            if [[ $IS_MUTUAL_MATCH -eq 1 ]]; then
                echo "UPDATE $TABLE
                      SET mutual_$MY_RHO = 1
                      WHERE id = $p;" | sqlite3 $DATABASE
            fi
        fi
    done
done

exit 0

