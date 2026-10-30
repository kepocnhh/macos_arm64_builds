#!/usr/local/bin/bash

unset BUILDS_CHECKS
unset BUILDS_JOBS
unset BUILDS_MIN_CPU
unset BUILDS_MIN_MACOS
unset BUILDS_PUBLIC_KEYS
unset BUILDS_SDK_ROOT
unset BUILDS_VERSION
unset BUILDS_WORKDIR

while [[ $# -gt 0 ]]; do
 if [[ $# -lt 2 ]]; then echo 'Wrong flags!' >&2; exit 1; fi
 case "$1" in
  '--checks')
   if [[ -v BUILDS_CHECKS ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_CHECKS="$2"; shift 2;;
  '--jobs')
   if [[ -v BUILDS_JOBS ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_JOBS="$2"; shift 2;;
  '--min_cpu')
   if [[ -v BUILDS_MIN_CPU ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_MIN_CPU="$2"; shift 2;;
  '--min_macos')
   if [[ -v BUILDS_MIN_MACOS ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_MIN_MACOS="$2"; shift 2;;
  '--public_key')
   BUILDS_PUBLIC_KEYS+=("$2"); shift 2;;
  '--sdk_root')
   if [[ -v BUILDS_SDK_ROOT ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_SDK_ROOT="$2"; shift 2;;
  '--version')
   if [[ -v BUILDS_VERSION ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_VERSION="$2"; shift 2;;
  '--workdir')
   if [[ -v BUILDS_WORKDIR ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_WORKDIR="$2"; shift 2;;
  *) echo "\"$1\" is not supported!" >&2; exit 1;;
 esac
done

#

if [[ -v BUILDS_CHECKS ]]; then
 case "${BUILDS_CHECKS}" in
  'false'|'true');;
  '') echo 'No checks!' >&2; exit 1;;
  *) echo 'Wrong checks!' >&2; exit 1;;
 esac
else
 BUILDS_CHECKS='false'
fi

if [[ "${BUILDS_JOBS}" == 'max' ]]; then
 BUILDS_JOBS="$(sysctl -n hw.ncpu)"
 if [[ $? != 0 ]]; then echo 'Get jobs error!' >&2; exit 1; fi
elif [[ -v BUILDS_JOBS ]]; then
 if [[ -z "${BUILDS_JOBS}" ]]; then echo 'No jobs!' >&2; exit 1; fi
else
 BUILDS_JOBS=1
fi

if [[ ! "${BUILDS_JOBS}" =~ ^[1-9][0-9]?$ ]]; then
 echo 'Wrong jobs!' >&2; exit 1; fi

if [[ -v BUILDS_MIN_CPU ]]; then
 case "${BUILDS_MIN_CPU}" in
  'm1'|'m2'|'m3'|'m4'|'m5');;
  '') echo 'No min cpu!' >&2; exit 1;;
  *) echo 'Wrong min cpu!' >&2; exit 1;;
 esac
else
 BUILDS_MIN_CPU='m1'
fi

if [[ -v BUILDS_MIN_MACOS ]]; then
 case "${BUILDS_MIN_MACOS}" in
  '14'|'15'|'26'|'27');;
  '') echo 'No min macos!' >&2; exit 1;;
  *) echo 'Wrong min macos!' >&2; exit 1;;
 esac
else
 BUILDS_MIN_MACOS='14'
fi

for BUILDS_PUBLIC_KEY in "${BUILDS_PUBLIC_KEYS[@]}"; do
 if [[ -z "${BUILDS_PUBLIC_KEY}" ]]; then
  echo 'No public key!' >&2; exit 1
 elif [[ -L "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is a symlink!" >&2; exit 1
 elif [[ ! -e "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" does not exist!" >&2; exit 1
 elif [[ ! -f "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is not a file!" >&2; exit 1
 elif [[ ! -s "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is empty!" >&2; exit 1
 fi
done

if [[ ! -v BUILDS_SDK_ROOT ]]; then
 BUILDS_SDK_ROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
 if [[ $? != 0 ]]; then echo 'Get sdk root error!' >&2; exit 1; fi
fi

if [[ -z "${BUILDS_SDK_ROOT}" ]]; then
 echo 'No sdk root!' >&2; exit 1
elif [[ ! -e "${BUILDS_SDK_ROOT}" ]]; then
 echo "\"${BUILDS_SDK_ROOT}\" does not exist!" >&2; exit 1
elif [[ ! -d "${BUILDS_SDK_ROOT}" ]]; then
 echo "\"${BUILDS_SDK_ROOT}\" is not a dir!" >&2; exit 1
fi

if [[ -z "${BUILDS_VERSION}" ]]; then
 echo 'No version!' >&2; exit 1; fi

if [[ ! -v BUILDS_WORKDIR ]]; then
 BUILDS_WORKDIR="$(pwd)"; fi

if [[ -z "${BUILDS_WORKDIR}" ]]; then
 echo 'No workdir!' >&2; exit 1
elif [[ -L "${BUILDS_WORKDIR}" ]]; then
 echo "\"${BUILDS_WORKDIR}\" is a symlink!" >&2; exit 1
elif [[ ! -e "${BUILDS_WORKDIR}" ]]; then
 echo "\"${BUILDS_WORKDIR}\" does not exist!" >&2; exit 1
elif [[ ! -d "${BUILDS_WORKDIR}" ]]; then
 echo "\"${BUILDS_WORKDIR}\" is not a dir!" >&2; exit 1
fi

#

BUILDS_SUBJECT='make'
BUILDS_ARCH='arm64'

#

SUBJECT="${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"
rm "${BUILDS_WORKDIR}/${SUBJECT}"

HTTP_CODE=$(curl -m 32 -w '%{http_code}' \
 --url "https://ftp.gnu.org/gnu/${BUILDS_SUBJECT}/${BUILDS_SUBJECT}-${BUILDS_VERSION}.tar.gz" \
 -o "${BUILDS_WORKDIR}/${SUBJECT}")

if [[ $? -ne 0 ]]; then
 echo "Request \"${SUBJECT}\" error!" >&2; exit 1
elif [[ "${HTTP_CODE}" != '200' ]]; then
 echo "Response \"${SUBJECT}\" error!" >&2; exit 1
fi

#

if [[ "${#BUILDS_PUBLIC_KEYS[@]}" -gt 0 ]]; then
 SUBJECT="${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.sig"
 rm "${BUILDS_WORKDIR}/${SUBJECT}"

 HTTP_CODE=$(curl -m 32 -w '%{http_code}' \
  --url "https://ftp.gnu.org/gnu/${BUILDS_SUBJECT}/${BUILDS_SUBJECT}-${BUILDS_VERSION}.tar.gz.sig" \
  -o "${BUILDS_WORKDIR}/${SUBJECT}")

 if [[ $? -ne 0 ]]; then
  echo "Request \"${SUBJECT}\" error!" >&2; exit 1
 elif [[ "${HTTP_CODE}" != '200' ]]; then
  echo "Response \"${SUBJECT}\" error!" >&2; exit 1
 fi

 GPG_HOMEDIR="$(mktemp -d)"
 GPG_ARGS=('--homedir' "${GPG_HOMEDIR}" '--no-default-keyring')
 for BUILDS_PUBLIC_KEY in "${BUILDS_PUBLIC_KEYS[@]}"; do GPG_ARGS+=('--keyring' "${BUILDS_PUBLIC_KEY}"); done
 GPG_ARGS+=('--verify' "${BUILDS_WORKDIR}/${SUBJECT}" "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz")
 gpg "${GPG_ARGS[@]}"

 if [[ $? != 0 ]]; then echo "Verify ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 rm "${BUILDS_WORKDIR}/${SUBJECT}"
 rm -rf "${GPG_HOMEDIR}"
fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/sources/"

tar -xf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz" \
 -C "${BUILDS_WORKDIR}/sources/"

if [[ $? != 0 ]]; then echo "Untar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"

#

rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/bin/"

(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && CC='/usr/bin/clang' \
  CFLAGS="-O3 -arch ${BUILDS_ARCH} -mcpu=apple-${BUILDS_MIN_CPU} -mtune=apple-${BUILDS_MIN_CPU} -mmacos-version-min=${BUILDS_MIN_MACOS}" \
  CPPFLAGS="-isysroot ${BUILDS_SDK_ROOT}" \
  LDFLAGS="-isysroot ${BUILDS_SDK_ROOT} -mmacos-version-min=${BUILDS_MIN_MACOS}" \
  ./configure --prefix='/usr/local')

if [[ $? != 0 ]]; then echo "Configure ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" && ./build.sh)

if [[ $? != 0 ]]; then echo "Build ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

if [[ "${BUILDS_CHECKS}" == 'true' ]]; then
 (set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
  && ./make check "-j${BUILDS_JOBS}")
 if [[ $? != 0 ]]; then echo "Test ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
fi

#

(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && ./make DESTDIR="${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" install)

if [[ $? != 0 ]]; then echo "Install ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

(set -x; cd "${BUILDS_WORKDIR}" \
 && "./bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/local/bin/${BUILDS_SUBJECT}" --version)
if [[ $? != 0 ]]; then echo "Get version ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

BUILDS_SUFFIX="macos-${BUILDS_MIN_MACOS}-${BUILDS_MIN_CPU}-${BUILDS_ARCH}"
[[ "${#BUILDS_PUBLIC_KEYS[@]}" -eq 0 ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-untrusted"
[[ "${BUILDS_CHECKS}" != 'true' ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-unchecked"

rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz"

(set -x; cd "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/local" \
 && tar -czf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz" "bin/${BUILDS_SUBJECT}")

if [[ $? != 0 ]]; then echo "Tar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
