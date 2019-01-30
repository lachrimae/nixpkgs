{ lib, stdenv, fetch, cmake, python, libcxxabi, fixDarwinDylibNames, version
, enableShared ? true }:

stdenv.mkDerivation rec {
  name = "libc++-${version}";

  src = fetch "libcxx" "1qlx3wlxrnc5cwc1fcfc2vhfsl7j4294hi8y5kxj8hy8wxsjd462";

  postUnpack = ''
    unpackFile ${libcxxabi.src}
    export LIBCXXABI_INCLUDE_DIR="$PWD/$(ls -d libcxxabi-${version}*)/include"
  '';

  patches = stdenv.lib.optional stdenv.hostPlatform.isMusl ../../libcxx-0001-musl-hacks.patch;

  prePatch = ''
    substituteInPlace lib/CMakeLists.txt --replace "/usr/lib/libc++" "\''${LIBCXX_LIBCXXABI_LIB_PATH}/libc++"
  '';

  preConfigure = ''
    # Get headers from the cxxabi source so we can see private headers not installed by the cxxabi package
    cmakeFlagsArray=($cmakeFlagsArray -DLIBCXX_CXX_ABI_INCLUDE_PATHS="$LIBCXXABI_INCLUDE_DIR")
  '' + lib.optionalString stdenv.hostPlatform.isMusl ''
    patchShebangs utils/cat_files.py
  '';
  nativeBuildInputs = [ cmake ] ++ stdenv.lib.optional stdenv.hostPlatform.isMusl python;

  buildInputs = [ libcxxabi ] ++ lib.optional stdenv.isDarwin fixDarwinDylibNames;

  cmakeFlags = [
    "-DLIBCXX_LIBCXXABI_LIB_PATH=${libcxxabi}/lib"
    "-DLIBCXX_LIBCPPABI_VERSION=2"
    "-DLIBCXX_CXX_ABI=libcxxabi"
  ] ++ stdenv.lib.optional stdenv.hostPlatform.isMusl "-DLIBCXX_HAS_MUSL_LIBC=1"
    ++ stdenv.lib.optional (stdenv.hostPlatform.useLLVM or false) "-DLIBCXX_USE_COMPILER_RT=ON"
    ++ stdenv.lib.optional stdenv.hostPlatform.isWasm [
      "-DLIBCXX_ENABLE_THREADS=OFF"
      "-DLIBCXX_ENABLE_FILESYSTEM=OFF"
    ] ++ stdenv.lib.optional (!enableShared) "-DLIBCXX_ENABLE_SHARED=OFF";

  enableParallelBuilding = true;

  linkCxxAbi = stdenv.isLinux;

  setupHooks = [
    ../../../../../build-support/setup-hooks/role.bash
    ./setup-hook.sh
  ];

  meta = {
    homepage = http://libcxx.llvm.org/;
    description = "A new implementation of the C++ standard library, targeting C++11";
    license = with stdenv.lib.licenses; [ ncsa mit ];
    platforms = stdenv.lib.platforms.all;
  };
}
