MAIN := main
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(notdir $(patsubst %/,%,$(dir $(MAKEFILE_PATH))))

## Standard `latexmk` call
PDFLATEX_ARGS := pdflatex -synctex=1 -interaction=nonstopmode -halt-on-error -file-line-error --shell-escape
define LATEXMK_PDFLATEX
	latexmk -pdflatex="$(PDFLATEX_ARGS)" -bibtex -pdf -jobname=$(basename $(1)) $(2)
endef

.PHONY: all main abstract clean clean-archive clean-bib clean-diff archive bib-fmt draft config build-dc FORCE
.PRECIOUS: $(MAIN)-diff-%.tex %-nourl.tex

main: $(MAIN).pdf

abstract: $(MAIN)-abstract.pdf

all: main abstract

%.pdf: %-nourl.tex biblio-nourl.bib FORCE
	$(call LATEXMK_PDFLATEX,$@,$<)

draft: $(MAIN)-nourl.tex biblio-nourl.bib FORCE
	latexmk -pdflatex="$(PDFLATEX_ARGS) %O '\def\Draft{}\input{%S}'" -bibtex -pdf -jobname=$(MAIN) $<

%-nourl.tex: %.tex
	sed -e 's/biblio\.bib/biblio-nourl\.bib/' -e 's/,biblio/,biblio-nourl/' -e 's/{biblio}/{biblio-nourl}/' $< > $@

biblio-nourl.bib: biblio.bib
	@ if [ ! -x scripts/create-biblio-nourl.sh ]; then \
		printf "\nERROR: the script required to generate '$@' is not executable. Run 'make config' to fix it.\n\n"; \
		exit 1; \
	fi
	scripts/create-biblio-nourl.sh $< > $@

## As it is possible to edit the paper also from Overleaf, we need to
## apply the following configs to have utility scripts working locally.
## Indeed, Overleaf will eventually turn off the executable bits of
## every file for security reasons, so we make Git ignore changes in
## executable bits (for this repo only) and set them properly.
config:
	git config --local core.fileMode false
	find . -iregex ".*\.sh" -exec chmod +x {} +

## Type `make bib-fmt` to have 'biblio.bib' formatted according to the rules
## defined in '.bibtoolrsc'.
bib-fmt: biblio.bib
	$(eval $@_temp_bib := $(shell mktemp -t bib-tmp.XXXXXXXXXX.bib))
	bibtool -r .bibtoolrsc -@ -i $< > $($@_temp_bib)
	mv $($@_temp_bib) $<

## Type `make clean` to remove all auto-generated files.
clean: clean-archive clean-bib clean-diff
	latexmk -C

clean-archive:
	rm -rf $(MAIN).zip $(MAIN)_arXiv.zip $(MAIN)_arXiv

clean-bib:
	rm -f biblio-nourl.bib

clean-diff:
	rm -rf *-diff-*

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

## Type `make arxiv` to generate a .zip, similar to the output of `make archive`,
## that can be used for an arXiv submission.
arxiv: archive
	unzip -o $(MAIN).zip
	arxiv_latex_cleaner $(MAIN)/
	zip -r $(MAIN)_arXiv.zip $(MAIN)/
	rm -r $(MAIN)/

## Type `make main-diff-<commit-id>.pdf` to get a .pdf showing the differences
## between <commit-id> and HEAD.
## Both versions are built (if needed) before using `latexdiff`, such that the
## corresponding .bbl files are available and the biblio can be included in the
## flattened diff. Therefore, the 'nourl' versions of the biblio are considered
## by default.
##
## NOTE: due to a latexdiff bug (https://github.com/ftilmann/latexdiff/issues/5),
## diffs in tables are not always handled correctly, so we ignore them altogether.
$(MAIN)-diff-%.pdf: $(MAIN)-diff-%.tex $(MAIN).pdf FORCE
	$(call LATEXMK_PDFLATEX,$@,$<)
	@printf "\nWARNING: latexdiff is set to ignore diffs in tables, you have to check them manually.\n"

$(MAIN)-diff-%.tex: /tmp/diff-%.dir
	cd $< && make clean; make config; make
	latexdiff --config="PICTUREENV=(?:picture|DIFnomarkup|table)[\w\d*@]*" --flatten \
		$</$(MAIN).tex $(MAIN).tex > $@

/tmp/diff-%.dir:
	git clone --reference $(shell git rev-parse --show-toplevel) \
		$(shell git remote -v | grep origin | grep fetch | sed -e 's/origin[[:blank:]]\+//' -e 's/ (fetch)//') $@ \
	&& cd $@ \
	&& git checkout $(patsubst /tmp/diff-%.dir,%,$@)

## Type `make build-dc` to trigger the build within the existing devcontainer
## directly from the host (i.e., no need to open the editor and attach).
##
## NOTE: 'jq' and 'python3-demjson' must be installed on the host to correctly
## parse the devcontainer name from '.devcontainer.json'.
build-dc:
	docker exec -it -u vscode -w /workspaces/$(CURRENT_DIR) \
		$(shell jsonlint -Sf .devcontainer.json | jq -r '.runArgs[]' | grep '^\-\-name\=' | cut -d'=' -f2) \
		make
