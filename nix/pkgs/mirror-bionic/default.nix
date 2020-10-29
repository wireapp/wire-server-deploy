{ lib
, makeWrapper
, runCommandNoCC
, aptly
, curl
, gnutar
, gnupg1orig }:

runCommandNoCC "mirror-bionic" {
  nativeBuildInputs = [ makeWrapper ];
} ''
  install -Dm755 ${./mirror-bionic.sh} $out/bin/mirror-bionic
  wrapProgram $out/bin/mirror-bionic --prefix PATH : '${lib.makeBinPath [ aptly curl gnupg1orig gnutar ]}'
''
