# [Choice] Ubuntu version: bionic, focal
ARG VARIANT=focal
FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT}

# Install additional OS packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        bash-completion \
        biber \
        bibtool \
        cpanminus \
        fontconfig \
        latexmk \
        make \
        poppler-utils \
        texlive-bibtex-extra \
        texlive-extra-utils \
        texlive-font-utils \
        texlive-fonts-recommended \
        texlive-latex-base \
        texlive-latex-extra \
        texlive-publishers \
        texlive-science \
        xzdec \
    && rm -rf /var/lib/apt/lists/*

# Install 'latexindent' Perl dependencies
RUN cpanm -fi Log::Dispatch::File YAML::Tiny File::HomeDir
