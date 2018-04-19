SHELL = /bin/bash

SESSION = ""
DATABASE = "matching/matching.sqlite3"
SDAPS = "../sdaps/sdaps.py"

MAILER = mail
RETURN_ADDRESS = ""
EMAIL_SUBJECT = "Speed-Meeting Matches"

# FIXME: This number is hard-coded; changes to card/stamped/ proper_
# pagination.tex are required. See that source file for more information.
NUMBER_CARDS =

##
## Default target
##
# Build all meta-targets, except for sending the emails. When a supplied data
# file is needed, this will fail and ask for it, even if it is unreasonable at
# this time.
#
# NB! `make send' is required to actually deliver the generated emails.
#
default: printable csv database email

##
## Meta make targets
##
# A list of higher-level targets allowing for a user-friendly interface.
#
.PHONY: printable csv database email send
printable: card/stamped/printable.pdf
csv: matching/matching.csv
database: matching/matching.sqlite3
email: email/queue/.makefile_drone

##
## Component make targets
##
#

# omr/questionnaire.pdf
#
# Creates the initial match card layout using SDAPS. If directory 'omr' already
# exists, it must be removed first or SDAPS will throw a fit.
#
# NB!  The actual target name is built by the recipe, but it is a mere
#      synecdoche for the entire 'omr' directory. (TODO: Check how make handles
#      directories as targets; I believe it treats them differently, but I'm not
#      sure.)
# XXX: The path of the border image must be manually specified in
#      'card/match_card.tex' before this can be run. This should be done
#      automatically.
omr/questionnaire.pdf: card/match_card.tex
	-rm -rf omr
	$(SDAPS) omr setup_tex card/match_card.tex

# card/stamped/stamped.pdf
#
# Stamp the cards, moving the outputted 'omr/stamped_*.pdf to its resting
# place in card/stamped/stamped.pdf
#
# XXX: I abuse the fact that the first stamped PDF is called
# 	   'stamped_1.pdf' by SDAPS and moving instead of copying; there is
# 	   probably a more robust -- if programmatically lengthy -- solution.
card/stamped/stamped.pdf: omr/questionnaire.pdf
	$(SDAPS) omr stamp -r $(NUMBER_CARDS)
	mv omr/stamped_1.pdf card/stamped/stamped.pdf

# card/stamped/printable.pdf
#
# Properly paginate match cards by combining them into lots of 4, via the
# 'card/proper_pagination.tex' utility LaTeX file.
#
# XXX: cd is used to (temporarily) make the working directory that where the
#      stamped files live. This is needed to resolve 'stamped.pdf' in the
#      TeX file correctly.
card/stamped/printable.pdf: card/stamped/stamped.pdf
	cd card/stamped && latexmk -pdf -outdir=latex_output proper_pagination.tex
	ln -sf latex_output/proper_pagination.pdf card/stamped/printable.pdf

# card/scan/scan_monochrome.tif
#
# Converts scan.pdf to a monochrome TIF via bin/pdf2monotif.
#
# TODO: Neither this Makefile nor bin/pdf2monotif attempt to crop the incoming
#       scan.pdf. This could lead to calamity if the scanner's scanned area is
#       substantially larger than the card. This can be accomplished with,
#       e.g.:
#           convert -density 300 card/scan/scan.pdf
#                   -crop 1275x1650+0+0 +repage card/scan/scan.pdf
#       where 1275px = 4.25in, 1650px = 5.5in at 300dpi.
card/scan/scan_monochrome.tif: card/scan/scan.pdf
	bin/pdf2monotif $< $@

# matching/matching.csv - Perform OMR on the scanned data
#
# Adds the monochrome scan to SDAPS, performs optical mark recognition, and
# exports the resulting data as matching/matching.csv, after refining it with
# bin/csv_preprocessing.
#
# OMR requires several steps: identifying the QR codes on all pages, reordering
# the pages into recto-verso pairs, and finally the mark recognition.
#
# The exported file from SDAPS will be stored as omr/data_1.csv. To avoid
# data_2.csv being created, the CSV file is moved to its final resting place
# rather than copied.
#
# FIXME: Rebuilding this file several times will result in duplicate entries,
#        leading to non-fatal errors upon SQLite-import.
# FIXME: Reordering the scans sometimes does more harm than good? It has added
#        additional "sheets" to the list, making the CSV data hard to interpret.
matching/matching.csv: card/scan/scan_monochrome.tif omr/questionnaire.pdf
	$(SDAPS) omr add $<
	$(SDAPS) omr recognize --identify
	$(SDAPS) omr reorder
	$(SDAPS) omr recognize
	$(SDAPS) omr csv export
	mv omr/data_1.csv $@
	bin/csv_preprocessing $@

# corrections - Verify and correct anomalies in the mark recognition
#
# Open the editing GUI provided by SDAPS and allow the user to make corrections.
# Then, re-export the CSV data.
#
# NB! Re-adding the scanned images will not and must not occur in this target.
#     Doing so is counterproductive and will dirty the 'omr' directory.
#
.PHONY: corrections
corrections: matching/matching.csv
	$(SDAPS) omr gui
	$(SDAPS) omr csv export
	mv -f omr/data_1.csv matching/matching.csv
	bin/csv_preprocessing matching/matching.csv

# matching/matching.sqlite3 - Generate SQLite database from SDAPS-produced CSV
#                             file and manually-entered contact data
#
# If it already exists, delete it so the CSV importing won't encounter
# collisions.
#
# FIXME: The initial OMR data is added to table 'raw', as required by
#        sqlite_refinement. This should probably be changed to something more
#        descriptive.
# FIXME: This target should be changed to reflect it contains the information
#        from both matching.csv and contact.csv.
matching/matching.sqlite3: matching/matching.csv matching/contact.csv
	-rm -f $@
	sqlite3 -csv $@ ".import matching/matching.csv raw"
	sqlite3 -csv $@ ".import matching/contact.csv contact"
	bin/sqlite_refinement $@

# email/queue/% - Generate emails for all participants
#
# For all persons whom we have contact information, generate the email
# containing their matches. In the instance an id was deleted since the previous
# run, remove everything in the email queue and start anew.
#
# NB! This target builds all emails regardless of the supplied % wildcard.
#
# To ensure this target isn't superfluously run, touch the file .makefile_drone
# to track when this was last built. Hence, 'make email/queue/.makefile_drone'
# will run only if the database has been changed, as desired.
#
#RECIPIENTS := $(addsuffix .html, $(shell sqlite3 matching/matching.sqlite3 \
#	"SELECT id FROM contact;"))
email/queue/%: matching/matching.sqlite3
	-rm -f email/queue/*.html
	for x in $$(sqlite3 $(DATABASE) "SELECT id FROM contact;"); do \
		printf '%s\n' "$$(bin/compose_email $$x)" > email/queue/$$x.html; \
	done
	touch email/queue/.makefile_drone

# send, email/sent/%.html - Delivers generated emails
#
# For all emails in the mail queue, sent the message to the intended recipient.
# Move the queued message into email/sent once this is done.
#
# The email address and message body are separated by filtering out the "TO:"
# present with the address and pruning it or excluding that line, respectively.
#
QUEUED_EMAILS := $(wildcard email/queue/*)
SENT_EMAILS := \
	$(foreach e, $(QUEUED_EMAILS), $(shell echo $e | sed -e 's/queue/sent/'))
send: email/queue/.makefile_drone $(SENT_EMAILS)
	@# XXX: Forces a failure if no emails have been queued. Run `make send' again
	@#      to correct this.
	@[ -n "$(SENT_EMAILS)" ]

email/sent/%.html: email/queue/%.html
	cat "$<" | grep -v "TO:" | $(MAILER) \
		-a 'Content-Type: text/html; charset=UTF-8' \
		-r $(RETURN_ADDRESS) \
		-s $(EMAIL_SUBJECT) \
		$$(cat "$<" | grep "TO:" | sed -e 's/.*<\(.*\)>/\1/')
	mv "$<" "$@"

##
## Clean make targets
##
#
# Allows for the removal of built files from other targets.
#

# clean - Removes some generated data
#
# Removes a conservative amount of files, only including those that can be
# readily regenerated.
#
# NB! This does not clean anything involving the match card template nor the
#     processed scans, in order to avoid the lengthy rebuilding of stamped.pdf
#     and scan_monochrome.tif, respectively. For this, use the 'squeaky_clean'
#     target instead.
#
.PHONY: clean
clean:
	-rm -f matching/matching.csv
	-rm -f matching/*.sqlite3
	-rm -f email/queue/*.html
	-rm -f email/queue/.makefile_drone

# squeaky_clean - Remove all generated files
#
# Reverts the session to its initial state, leaving both the files supplied by
# the user and the sent email list intact.
#
.PHONY: squeaky_clean
squeaky_clean: clean
	-rm -rf omr
	-rm -f card/stamped/stamped.pdf
	-rm -rf card/stamped/latex_output
	-rm -f card/stamped/printable.pdf
	-rm -f card/scan/scan_monochrome.tif

# crystal_clean - Remove all files, including non-regeneratable ones
#
# Delete everything, no take backs.
#
# WARNING! ###
# This will make it impossible to recover any information from the event if
# the physical match cards or scans made thereof were destroyed or are
# otherwise nonexistent.
#
# WARNING! ###
# This removes sent emails. After this, it will likely be prohibitively
# difficult to know who had mail already delivered to them.
#
.PHONY: crystal_clean
crystal_clean: squeaky_clean
	-rm -f card/scan/scan.pdf
	-rm -f matching/contact.csv
	-rm -f email/sent/*.html

