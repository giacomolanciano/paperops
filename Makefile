MAIN := main
BIB_FILES := biblio.bib
BIB_NOURL_FILES := $(foreach bib_file,$(BIB_FILES),$(basename $(bib_file))-nourl.bib)
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

%.pdf: %-nourl.tex $(BIB_NOURL_FILES) FORCE
	$(call LATEXMK_PDFLATEX,$@,$<)

draft: $(MAIN)-nourl.tex $(BIB_NOURL_FILES) FORCE
	latexmk -pdflatex="$(PDFLATEX_ARGS) %O '\def\Draft{}\input{%S}'" -bibtex -pdf -jobname=$(MAIN) $<

%-nourl.tex: %.tex
	cp -a $< $@
	for bib_file_basename in $(foreach bib_file,$(BIB_FILES),$(basename $(bib_file))); do \
		sed -i \
			-e "s/$${bib_file_basename}\.bib/$${bib_file_basename}-nourl\.bib/" \
			-e "s/,$${bib_file_basename}/,$${bib_file_basename}-nourl/" \
			-e "s/{$${bib_file_basename}}/{$${bib_file_basename}-nourl}/" \
			$@; \
	done

%-nourl.bib: %.bib
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

## Type `make bib-fmt` to have BIB_FILES formatted according to the rules
## defined in '.bibtoolrsc'.
bib-fmt: $(BIB_FILES)
	$(eval $@_temp_bib := $(shell mktemp -t bib-tmp.XXXXXXXXXX.bib))
	for bib_file in $(BIB_FILES); do \
		echo "Formatting '$$bib_file'..."; \
		bibtool -r .bibtoolrsc -@ -i $$bib_file > $($@_temp_bib); \
		mv $($@_temp_bib) $$bib_file; \
		echo; \
	done

## Type `make clean` to remove all auto-generated files.
clean: clean-archive clean-bib clean-diff
	latexmk -C

clean-archive:
	rm -rf $(MAIN).zip $(MAIN)/ $(MAIN)-safe.zip $(MAIN)-safe/ $(MAIN)_arXiv.zip $(MAIN)_arXiv/

clean-bib:
	rm -f *-nourl.bib

clean-diff:
	rm -rf *-diff-*

## Type `make archive` to generate a .zip containing all the files that are
## strictly necessary to compile the document (i.e., images and other material
## that are not actually referenced in .tex files will not be included).
## This is useful for preparing a camera-ready submission that do not disclose
## potentially sensitive material.
##
## NOTE: the .dep file produced by the 'snapshot' package may also list temporary
## files produced, and deleted, during the build. Such temporary files are not
## required to build, but 'bundledoc' fails to create the archive as they are
## listed but not found. As a workaround, we remove the related lines from the
## .dep file before using 'bundledoc'.
archive: $(MAIN).dep $(MAIN).pdf
	sed -i -e '/\.w18"}/d' $<
	bundledoc --config=.bundledoc.cfg \
		--texfile=$(MAIN).tex \
		--manifest="" \
		--localonly \
		--exclude=.out \
		--include=*.bib \
		--include=*.bst \
		--include=*.fd \
		--include=*.map \
		--include=*.pfb \
		--include=*.tfm \
		$<

## Type `make archive-safe` to generate a .zip, similar to the output of `make archive`,
## but with all comments stripped down from .tex files (e.g., for an arXiv submission).
##
## NOTE: due to how `arxiv_latex_cleaner` filter the source files, .pdf files generated
## from .eps file must be manually copied over.
archive-safe: clean-archive archive
	unzip -o $(MAIN).zip
	arxiv_latex_cleaner --keep_bib $(MAIN)/
	mv $(MAIN)_arXiv/ $(MAIN)-safe/
	cp -f img/*-eps-converted-to.pdf $(MAIN)-safe/img/ || true
	zip -r $(MAIN)-safe.zip $(MAIN)-safe/

## Type `make main-diff-<COMMIT-ID>.pdf` to get a .pdf showing the differences
## between <COMMIT-ID> and HEAD.
## Both versions are built (if needed) before using `latexdiff`, such that the
## corresponding .bbl files are available and the biblio can be included in the
## flattened diff. Therefore, the 'nourl' versions of the biblio are considered
## by default.
## In case of build errors, it is still possible to manually fix `latexdiff`'s
## .tex output and re-trigger the build with the same command (the .tex file
## won't be overwritten).
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
