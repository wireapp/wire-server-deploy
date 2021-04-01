FROM nixos/nix

COPY . /wire-server-deploy

RUN apk add -u bash git

RUN nix-build /wire-server-deploy/default.nix -A env --out-link /.nix-env

RUN rm -rf /wire-server-deploy

ENV PATH="/.nix-env/bin:$PATH"
ENV LOCALHOST_PYTHON="/.nix-env/bin/python"

