PANDOC=$(shell which pandoc)
MARKDOWNPP=../vendored/bin/markdown-pp
PYMARKDOWNLNT=$(shell which pymarkdownlnt)
ifeq ($(STYLE),)
STYLE="working_draft"
endif
PDF_MARGINS=--variable margin-top=15 --variable margin-bottom=25 --variable margin-left=0 --variable margin-right=10
PDF_FOOTER=--pdf-engine-opt="--footer-right" --pdf-engine-opt="[page] of [topage]" --pdf-engine-opt="--footer-font-name" --pdf-engine-opt="Palatino" --pdf-engine-opt="--footer-font-size" --pdf-engine-opt="8"
SPEC_SOURCE_FILES=$(filter-out spec.md, $(wildcard *.md*)) $(wildcard columns/*.md*) $(wildcard attributes/*.md*) $(wildcard appendix/*.md*)
SPEC_SOURCE_MDFILES=$(filter-out %.mdpp, $(SPEC_SOURCE_FILES))
export TOCDEPTH=2
all: spec.md spec.pdf spec.html

spec.pdf: spec.md
	$(PANDOC) spec.md -o $@ -f gfm --css=styles/${STYLE}.css $(PDF_MARGINS) $(PDF_FOOTER) --pdf-engine=wkhtmltopdf

spec.html: 
	$(PANDOC) spec.md -o $@ -f gfm -s --css=styles/${STYLE}_html.css

spec.md: $(SPEC_SOURCE_FILES)
ifneq ("$(wildcard versions/${STYLE}.md)","")
	cp versions/${STYLE}.md version.md
else
	cp versions/working_draft.md version.md
endif
	./validate_includes.py columns
	./validate_includes.py attributes
	./validate_includes.py metadata
	./validate_includes.py metadata/data_generator
	./validate_includes.py metadata/schema
	./validate_includes.py metadata/schema/column_definition
	./validate_includes.py appendix
	./validate_includes.py appendix/examples
	./validate_includes.py appendix/examples/metadata_examples
	PYTHONPATH=../vendored/ $(MARKDOWNPP) spec.mdpp -o $@
	$(PYMARKDOWNLNT) --config markdownlnt.cfg scan $(SPEC_SOURCE_MDFILES)
	$(PYMARKDOWNLNT) --config markdownlnt.cfg scan $@

clean:
	rm -f spec.pdf spec.html spec.md version.md
