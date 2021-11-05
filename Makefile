MAIN=main
PAPERS=$(MAIN)

.PHONY: all clean clean-archive clean-bib clean-diff archive bib-fmt FORCE
.PRECIOUS: $(MAIN)-diff-%.tex

all: $(MAIN).pdf

%.pdf: %.tex biblio-nourl.bib FORCE
	latexmk -pdflatex='pdflatex -file-line-error -synctex=1' -bibtex -pdf $<

	@ if [ -n "$(strip $(findstring -diff-,$@))" ]; then \
		printf "\nWARNING: latexdiff is set to ignore diffs in tables, you have to check them manually.\n"; \
	fi

biblio-nourl.bib: biblio.bib
	scripts/create-biblio-nourl.sh $< > $@

clean: clean-archive clean-bib clean-diff
	latexmk -C

clean-archive:
	rm -rf $(MAIN).zip $(MAIN)_arXiv.zip $(MAIN)_arXiv

clean-bib:
	rm -f biblio-nourl.bib

clean-diff:
	rm -f *-diff-*

## Type `make archive` to generate a .zip containing all the files that are
## strictly necessary to compile the document (i.e., images and other material
## that are not actually referenced in .tex files will not be included).
## This is useful for preparing a camera-ready submission that do not disclose
## potentially sensitive material.
archive: $(MAIN).pdf
	bundledoc --config=.bundledoc.cfg --localonly --manifest="" \
	--exclude=.out \
	--include=*.bib \
	--include=*.bst \
	$(MAIN).dep

arxiv: archive
	unzip -o $(MAIN).zip
	arxiv_latex_cleaner $(MAIN)/
	zip -r $(MAIN)_arXiv.zip $(MAIN)/
	rm -r $(MAIN)/

## Type `make bib-fmt` to have 'biblio.bib' formatted according to the rules
## defined in '.bibtoolrsc'.
bib-fmt: biblio.bib
	$(eval $@_temp_bib := $(shell mktemp -t bib-tmp.XXXXXXXXXX.bib))
	bibtool -r .bibtoolrsc -@ -i $< > $($@_temp_bib)
	mv $($@_temp_bib) $<

## Type `make main-diff-<commit-id>.pdf` to get a .pdf showing the differences
## between <commit-id> and HEAD.
## NOTE: due to a latexdiff bug (https://github.com/ftilmann/latexdiff/issues/5),
## diffs in tables are not always handled correctly, so we ignore them altogether.
define diff_templ
$(1)-diff-%.tex: /tmp/diff-%.dir
	latexdiff --config="PICTUREENV=(?:picture|DIFnomarkup|table)[\w\d*@]*" --flatten $$</$(1).tex $(1).tex > $$@
endef

$(foreach p,$(PAPERS),$(eval $(call diff_templ,$(p))))

/tmp/diff-%.dir:
	git clone --reference $(shell git rev-parse --show-toplevel) \
	$(shell git remote -v | grep origin | grep fetch | sed -e 's/origin[[:blank:]]\+//' -e 's/ (fetch)//') $@ \
	&& cd $@ \
	&& git checkout $(patsubst /tmp/diff-%.dir,%,$@)
