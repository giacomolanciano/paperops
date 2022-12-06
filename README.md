# latex-paper-template

A comprehensive template repository for academic paper writing with LaTeX.

## Features

- Support for a hybrid local/[Overleaf](https://overleaf.com/) collaboration workflow.
- Support for a [devcontainer](https://containers.dev/)-based workflow, [batteries included](https://github.com/giacomolanciano/devcontainer-latex).
- Automatic bibliography formatting and compaction.
- Automatic generation of difference reports (between versions).
- Automatic minimal archive generation for camera-ready and/or [arXiv](https://arxiv.org/) submissions.
- Draft mode with sensible defaults.
- [GitHub Actions](https://docs.github.com/en/actions) to remotely build the latest version
  [on-demand](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow).

## Dependencies

The features provided by this template depend on tools such as:
[`make`](https://www.gnu.org/software/make/),
[`latexmk`](https://ctan.org/pkg/latexmk),
[`bibtool`](https://www.ctan.org/pkg/bibtool),
[`latexdiff`](https://www.ctan.org/pkg/latexdiff),
[`bundledoc`](https://ctan.org/pkg/bundledoc),
etc.

It is recommended to use the companion [`devcontainer-latex`](https://github.com/giacomolanciano/devcontainer-latex) to
have all the dependencies installed in a Docker container. Editors like [VS Code](https://code.visualstudio.com/docs/devcontainers/create-dev-container)
can automatically create a devcontainer using the included [`.devcontainer.json`](.devcontainer.json). Otherwise, it is
possible to manually start the container:

```bash
$ docker pull ghcr.io/giacomolanciano/devcontainer-latex:<VERSION>
...
$ docker run -it \
    -u vscode \
    -e UID=$(id -u) \
    -e GID=$(id -g) \
    -v </PATH/TO/LATEX/PROJECT>:/workspaces/<LATEX-PROJECT-NAME> \
    -w /workspaces/<LATEX-PROJECT-NAME> \
    --name <CONTAINER-NAME> \
    ghcr.io/giacomolanciano/devcontainer-latex:<VERSION> \
    bash
```

Alternatively, if having all the dependencies installed on the bare machine is preferred, just adapt the configuration
steps included in the [`Dockerfile`](https://github.com/giacomolanciano/devcontainer-latex/blob/master/Dockerfile).

## Usage

### Setup

In order to start a new LaTeX project from this template:

1. Create a new repo.
    - To enable collaboration via Overleaf, it is recommended to first create a project from there and clone the
      associated Git repo.
    - Otherwise, just initialize a new Git repo locally.
2. Copy the contents from this template to the new repo.
3. Push to the remote(s).
    - To enable collaboration via Overleaf, it is recommended to use the associated Git repo as `origin`, to also track
      the changes made via the web GUI. Consider that Overleaf only allows for having a single branch, and force-pushing
      is not permitted.
    - To use the GitHub Actions, it is necessary to setup a GitHub remote. If collaboration via Overleaf is enabled, it
      is recommended not to share push access to the GitHub remote with collaborators, to avoid confusion. The GitHub
      remote will have to be *manually* synced to align with the latest version on Overleaf.
    - Before pushing, it is recommended to use `git pull --rebase` to keep the history linear and prevent the push from
      being rejected by the Overleaf remote.

**NOTE:** Alternatively, it is possible to automatically
[create](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)
a new GitHub remote from this template. However, consider that enabling Overleaf later will be trickier.

### CLI

The included [Makefile](Makefile) provides the following commands:

| Command                          | Description                                                                                                |
| :------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| `make`                           | Build `main.pdf`, the complete manuscript.                                                                 |
| `make main<SUFFIX>.pdf`          | Build a PDF from `main<SUFFIX>.tex`, useful to maintain multiple versions with different document classes. |
| `make abstract`                  | Build `main-abstract.pdf`, a document containing title and abstract only.                                  |
| `make all`                       | Build both `main.pdf` and `main-abstract.pdf`.                                                             |
| `make draft`                     | Build `main.pdf` in draft mode, useful to make editing faster (e.g., when there are many figures).         |
| `make config`                    | Apply initial configurations.                                                                              |
| `make bib-fmt`                   | Format `biblio.bib`.                                                                                       |
| `make main-diff-<COMMIT-ID>.pdf` | Build a PDF highlighting the differences between the current and the `<COMMIT-ID>` version.                |
| `make archive`                   | Generate a .zip containing all the files that are strictly necessary to build `main.pdf`.                  |
| `make arxiv`                     | Generate a .zip, similar to the output of `make archive`, ready for an arXiv submission.                   |
| `make clean`                     | Remove all auto-generated files.                                                                           |
| `make build-dc`                  | Trigger the build within the **existing** devcontainer directly from the host.                             |

## FAQs

### Why do I see `main-nourl.tex` and `biblio-nourl.bib` being generated when building?

By default, the build process triggered by `make` generates a compact version of the bibliography, by removing URLs
deemed [unnecessary](scripts/create-biblio-nourl.sh). However, since Overleaf does not support custom `Makefile`s, we
generate alternative versions of the main document and the bibliography, that are the ones actually used to build
`main.pdf`. In this way, collaborators working from Overleaf can still have the manuscript built, although with the
non-compact version of the bibliography.

### How to use publishers-provided document classes?

For simplicity, this template is set to use the standard `article` document class. However, it should be fairly easy to
switch to alternative classes, such as those provided by publishers like
[ACM](https://www.acm.org/publications/proceedings-template) or
[IEEE](https://template-selector.ieee.org/secure/templateSelector/).

To have this template working with another document class, make sure to:

- Include the `\usepackage{...}` instructions in the **same order** as they appear in this template.
- Include the following instruction as the **first line** to use the archiving features:

    ```latex
    \RequirePackage{snapshot}
    ```

- Include the following block to use the draft mode feature:

    ```latex
    \ifdefined\Draft
        ...
    \fi
    ```

**NOTE:** document classes provided by major publishers are usually readily available via the `texlive-publishers`
package, that is included in [`devcontainer-latex`](https://github.com/giacomolanciano/devcontainer-latex). However, to
ensure portability, it is recommended to copy their relevant source files (e.g., `*.bst`, `*.cls`, `*.sty`, etc.) in the
project.

### Why can't I interact with my Git remote, via SSH, from the devcontainer?

If the container is automatically created with VS Code, it is probably enough to set the `ssh-agent` running on the
host to [share](https://code.visualstudio.com/docs/devcontainers/containers#_using-ssh-keys) the required SSH keys with
the container (**NOTE:** it may be necessary to re-build the container).

However, if the container is started [manually](#dependencies), the connection with the `ssh-agent` running on the
host is not automatically set. In this case, it is always possible to run Git remote-related commands directly from the
host.

## Acknowledgments

This project is maintained by [Giacomo Lanciano](https://github.com/giacomolanciano). It has been developed and
battle-tested during his PhD, with (way more than) a little help from [Tommaso Cucinotta](https://retis.sssup.it/~tommaso/eng/index.html).

## License

Distributed under the [MIT License](https://github.com/giacomolanciano/latex-paper-template/blob/master/LICENSE).
