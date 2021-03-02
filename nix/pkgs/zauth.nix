{ stdenv, fetchurl }:

stdenv.mkDerivation {
  name = "zauth";
  src = fetchurl {
    # TODO update binaries
    url = "https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/khan-static-x86_64-0.4.31";
    sha256 = "0f2rv2kxk6qzvplbcr5s0nkdir5prg3hc67x3lfidfpym8p43ii1";
  };

  # Since this is a static binary, we don't want to unpack, build, or install anything.
  # instead, just copy the binary:
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    cp $src zauth
    install -Dm0755 zauth -t $out/bin
  '';

}
