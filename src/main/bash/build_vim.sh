#!/usr/local/bin/bash

unset BUILDS_CHECKS
unset BUILDS_FEATURES
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
  '--features')
   if [[ -v BUILDS_FEATURES ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_FEATURES="$2"; shift 2;;
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

#

if [[ -v BUILDS_FEATURES ]]; then
 echo 'Not implemented!' >&2; exit 1 # todo
else
 BUILDS_FEATURES='tiny'
fi

#

if [[ "${BUILDS_JOBS}" == 'max' ]]; then
 BUILDS_JOBS="$(/usr/sbin/sysctl -n hw.ncpu)"
 if [[ $? != 0 ]]; then echo 'Get jobs error!' >&2; exit 1; fi
elif [[ -v BUILDS_JOBS ]]; then
 if [[ -z "${BUILDS_JOBS}" ]]; then echo 'No jobs!' >&2; exit 1; fi
else
 BUILDS_JOBS=1
fi

if [[ ! "${BUILDS_JOBS}" =~ ^[1-9][0-9]?$ ]]; then
 echo 'Wrong jobs!' >&2; exit 1; fi

#

if [[ "${BUILDS_MIN_CPU}" == 'current' ]]; then
 BUILDS_MIN_CPU="$(/usr/sbin/sysctl -nx hw.cpufamily)"
 if [[ $? != 0 ]]; then echo 'Get cpu error!' >&2; exit 1; fi
 case "${BUILDS_MIN_CPU}" in
  '0x1b588bb3') BUILDS_MIN_CPU='m1';;
  '0xda33d83d') BUILDS_MIN_CPU='m2';;
  '0xfa33415e'|'0x5f4dea93'|'0x72015832') BUILDS_MIN_CPU='m3';;
  '0x6f5129ac'|'0x17d5b93a') BUILDS_MIN_CPU='m4';;
  '0x1d5a87e8'|'0xf76c5b1a') BUILDS_MIN_CPU='m5';;
  *) echo 'Wrong cpu!' >&2; exit 1;;
 esac
elif [[ -v BUILDS_MIN_CPU ]]; then
 case "${BUILDS_MIN_CPU}" in
  'm1'|'m2'|'m3'|'m4'|'m5');;
  '') echo 'No min cpu!' >&2; exit 1;;
  *) echo 'Wrong min cpu!' >&2; exit 1;;
 esac
else
 BUILDS_MIN_CPU='m1'
fi

#

if [[ "${BUILDS_MIN_MACOS}" == 'current' ]]; then
 BUILDS_MIN_MACOS="$(/usr/bin/sw_vers -productVersion)"
 if [[ $? != 0 ]]; then echo 'Get macos version error!' >&2; exit 1; fi
elif [[ -v BUILDS_MIN_MACOS ]]; then
 case "${BUILDS_MIN_MACOS}" in
  '14'|'15'|'26'|'27');;
  '') echo 'No min macos!' >&2; exit 1;;
  *) echo 'Wrong min macos!' >&2; exit 1;;
 esac
else
 BUILDS_MIN_MACOS='14'
fi

if [[ ! "${BUILDS_MIN_MACOS}" =~ ^[1-9][0-9]?(\.(0|[1-9][0-9]?)){0,2}$ ]]; then
 echo 'Wrong min macos!' >&2; exit 1; fi

#

for ((i = 0; i < ${#BUILDS_PUBLIC_KEYS[@]}; i+=1)); do
 BUILDS_PUBLIC_KEY="${BUILDS_PUBLIC_KEYS[i]}"
 if [[ -z "${BUILDS_PUBLIC_KEY}" ]]; then
  echo 'No public key!' >&2; exit 1
 elif [[ -L "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is a symlink!" >&2; exit 1
 fi
 BUILDS_PUBLIC_KEY="$(realpath -- "${BUILDS_PUBLIC_KEY}")"
 if [[ $? != 0 ]]; then
  echo 'Realpath public key error!' >&2; exit 1
 elif [[ ! -e "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" does not exist!" >&2; exit 1
 elif [[ ! -f "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is not a file!" >&2; exit 1
 elif [[ ! -s "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is empty!" >&2; exit 1
 fi
 BUILDS_PUBLIC_KEYS[i]="${BUILDS_PUBLIC_KEY}"
done

#

if [[ ! -v BUILDS_SDK_ROOT ]]; then
 BUILDS_SDK_ROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
 if [[ $? != 0 ]]; then echo 'Get sdk root error!' >&2; exit 1; fi
fi

if [[ -z "${BUILDS_SDK_ROOT}" ]]; then echo 'No sdk root!' >&2; exit 1; fi

BUILDS_SDK_ROOT="$(realpath -- "${BUILDS_SDK_ROOT}")"
if [[ $? != 0 ]]; then
 echo 'Realpath sdk root error!' >&2; exit 1
elif [[ ! -e "${BUILDS_SDK_ROOT}" ]]; then
 echo "\"${BUILDS_SDK_ROOT}\" does not exist!" >&2; exit 1
elif [[ ! -d "${BUILDS_SDK_ROOT}" ]]; then
 echo "\"${BUILDS_SDK_ROOT}\" is not a dir!" >&2; exit 1
fi

#

if [[ -z "${BUILDS_VERSION}" ]]; then echo 'No version!' >&2; exit 1; fi

#

if [[ ! -v BUILDS_WORKDIR ]]; then
 BUILDS_WORKDIR="$(pwd)"
 if [[ $? != 0 ]]; then echo 'Get workdir error!' >&2; exit 1; fi
fi

if [[ -z "${BUILDS_WORKDIR}" ]]; then
 echo 'No workdir!' >&2; exit 1
elif [[ -L "${BUILDS_WORKDIR}" ]]; then
 echo "\"${BUILDS_WORKDIR}\" is a symlink!" >&2; exit 1
fi

BUILDS_WORKDIR="$(realpath -- "${BUILDS_WORKDIR}")"
if [[ $? != 0 ]]; then
 echo 'Realpath workdir error!' >&2; exit 1
elif [[ ! -e "${BUILDS_WORKDIR}" ]]; then
 echo "\"${BUILDS_WORKDIR}\" does not exist!" >&2; exit 1
elif [[ ! -d "${BUILDS_WORKDIR}" ]]; then
 echo "\"${BUILDS_WORKDIR}\" is not a dir!" >&2; exit 1
fi

#

BUILDS_SUBJECT='vim'
BUILDS_ARCH='arm64'
BUILDS_SUFFIX="macos-${BUILDS_MIN_MACOS}-${BUILDS_MIN_CPU}-${BUILDS_ARCH}"

#

SUBJECT="${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"
rm "${BUILDS_WORKDIR}/${SUBJECT}"
HTTP_CODE=$(curl -m 32 -w '%{http_code}' \
 -L --url "https://github.com/${BUILDS_SUBJECT}/${BUILDS_SUBJECT}/archive/refs/tags/v${BUILDS_VERSION}.tar.gz" \
 -o "${BUILDS_WORKDIR}/${SUBJECT}")
if [[ $? -ne 0 ]]; then
 echo "Request \"${SUBJECT}\" error!" >&2; exit 1
elif [[ "${HTTP_CODE}" != '200' ]]; then
 echo "Response \"${SUBJECT}\" error!" >&2; exit 1
fi

#

if [[ "${#BUILDS_PUBLIC_KEYS[@]}" -gt 0 ]]; then
 echo 'Not implemented!' >&2; exit 1 # todo
fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/sources/"

#

tar -xf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz" -C "${BUILDS_WORKDIR}/sources/"
if [[ $? != 0 ]]; then echo "Untar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"

#

rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/bin/"
:> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}-j${BUILDS_JOBS}.log"

#

TIME_START="$(date +%s%3N)"
(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && CC='/usr/bin/clang' \
  CFLAGS="-O3 -arch ${BUILDS_ARCH} -mcpu=apple-${BUILDS_MIN_CPU} -mtune=apple-${BUILDS_MIN_CPU} -mmacos-version-min=${BUILDS_MIN_MACOS}" \
  CPPFLAGS="-isysroot ${BUILDS_SDK_ROOT}" \
  LDFLAGS="-isysroot ${BUILDS_SDK_ROOT} -mmacos-version-min=${BUILDS_MIN_MACOS}" \
  MAKEFLAGS='' GNUMAKEFLAGS='' CONFIG_SITE='/dev/null' \
  ./configure --prefix='/usr/local' --with-features="${BUILDS_FEATURES}" --disable-gui --without-x)
if [[ $? != 0 ]]; then echo "Configure ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
TIME_NOW="$(date +%s%3N)"
echo "Configure ${BUILDS_SUBJECT}-${BUILDS_VERSION} $(((TIME_NOW - TIME_START) / 1000))s" \
 >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}-j${BUILDS_JOBS}.log"

#
echo 'Not implemented!' >&2; exit 1 # todo
TIME_START="$(date +%s%3N)"
(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && MAKEFLAGS='' GNUMAKEFLAGS='' make "-j${BUILDS_JOBS}")
if [[ $? != 0 ]]; then echo "Make ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
TIME_NOW="$(date +%s%3N)"
echo "Make ${BUILDS_SUBJECT}-${BUILDS_VERSION} $(((TIME_NOW - TIME_START) / 1000))s" \
 >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}-j${BUILDS_JOBS}.log"

#
echo 'Not implemented!' >&2; exit 1 # todo
if [[ "${BUILDS_CHECKS}" == 'true' ]]; then
 TIME_START="$(date +%s%3N)"
 (set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
  && MAKEFLAGS='' GNUMAKEFLAGS='' make check "-j${BUILDS_JOBS}")
 if [[ $? != 0 ]]; then echo "Test ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 TIME_NOW="$(date +%s%3N)"
 echo "Test ${BUILDS_SUBJECT}-${BUILDS_VERSION} $(((TIME_NOW - TIME_START) / 1000))s" \
  >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}-j${BUILDS_JOBS}.log"
fi

#
echo 'Not implemented!' >&2; exit 1 # todo
(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && MAKEFLAGS='' GNUMAKEFLAGS='' make DESTDIR="${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" install)
if [[ $? != 0 ]]; then echo "Install ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#
echo 'Not implemented!' >&2; exit 1 # todo
(set -x; cd "${BUILDS_WORKDIR}" \
 && "./bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/local/bin/${BUILDS_SUBJECT}" --version)
if [[ $? != 0 ]]; then echo "Get version ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#
echo 'Not implemented!' >&2; exit 1 # todo
[[ "${#BUILDS_PUBLIC_KEYS[@]}" -eq 0 ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-untrusted"
[[ "${BUILDS_CHECKS}" != 'true' ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-unchecked"

rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz"
(set -x; cd "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/local/" \
 && tar -czf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz" './bin')
if [[ $? != 0 ]]; then echo "Tar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#
echo 'Not implemented!' >&2; exit 1 # todo
rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
