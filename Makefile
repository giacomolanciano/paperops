MAIN=main
PAPERS=$(MAIN)
PDFLATEX_ARGS := pdflatex -synctex=1 -interaction=nonstopmode -halt-on-error -file-line-error --shell-escape

.PHONY: all main abstract clean clean-archive clean-bib clean-diff archive bib-fmt draft config FORCE
.PRECIOUS: $(MAIN)-diff-%.tex %-nourl.tex

main: $(MAIN).pdf

abstract: $(MAIN)-abstract.pdf

all: main abstract

## As it is possible to edit the paper also from Overleaf, we need to
## apply the following configs to have utility scripts working locally.
## Indeed, Overleaf will eventually turn off the executable bits of
## every file for security reasons, so we make Git ignore changes in
## executable bits (for this repo only) and set them properly.
config:
	git config --local core.fileMode false
	find . -iregex ".*\.sh" -exec chmod +x {} +

%-nourl.tex: %.tex
	sed -e 's/biblio\.bib/biblio-nourl\.bib/' -e 's/,biblio/,biblio-nourl/' -e 's/{biblio}/{biblio-nourl}/' $< > $@

%.pdf: %-nourl.tex biblio-nourl.bib FORCE
	latexmk -pdflatex="$(PDFLATEX_ARGS)" -bibtex -pdf -jobname=$(basename $@) $<

	@ if [ -n "$(strip $(findstring -diff-,$@))" ]; then \
		printf "\nWARNING: latexdiff is set to ignore diffs in tables, you have to check them manually.\n"; \
	fi

draft: $(MAIN)-nourl.tex biblio-nourl.bib FORCE
	latexmk -pdflatex="$(PDFLATEX_ARGS) %O '\def\Draft{}\input{%S}'" -bibtex -pdf -jobname=$(MAIN) $<

biblio-nourl.bib: biblio.bib
	@ if [ ! -x scripts/create-biblio-nourl.sh ]; then \
		printf "\nERROR: the script required to generate '$@' is not executable. Run 'make config' to fix it.\n\n"; \
		exit 1; \
	fi
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
	cd $(patsubst /tmp/diff-%-nourl.dir,/tmp/diff-%.dir,$$<) && make clean; make config; make
	latexdiff --config="PICTUREENV=(?:picture|DIFnomarkup|table)[\w\d*@]*" --flatten $$</$(1).tex $(1).tex > $$@
endef

$(foreach p,$(PAPERS),$(eval $(call diff_templ,$(p))))

/tmp/diff-%.dir:
	git clone --reference $(shell git rev-parse --show-toplevel) \
	$(shell git remote -v | grep origin | grep fetch | sed -e 's/origin[[:blank:]]\+//' -e 's/ (fetch)//') $(patsubst /tmp/diff-%-nourl.dir,/tmp/diff-%.dir,$@) \
	&& cd $(patsubst /tmp/diff-%-nourl.dir,/tmp/diff-%.dir,$@) \
	&& git checkout $(patsubst /tmp/diff-%-nourl.dir,%,$@)
