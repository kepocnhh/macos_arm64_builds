#!/usr/local/bin/bash

unset BUILDS_PUBLIC_KEY
unset BUILDS_VERSION
unset BUILDS_WORKDIR
unset BUILDS_SDKROOT
unset BUILDS_MINVERSION
unset BUILDS_JOBS
unset BUILDS_CHECKS

while [[ $# -gt 0 ]]; do
 if [[ $# -lt 2 ]]; then echo 'Wrong flags!' >&2; exit 1; fi
 case "$1" in
  '--public_key')
   if [[ -v BUILDS_PUBLIC_KEY ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_PUBLIC_KEY="$2"; shift 2;;
  '--version')
   if [[ -v BUILDS_VERSION ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_VERSION="$2"; shift 2;;
  '--workdir')
   if [[ -v BUILDS_WORKDIR ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_WORKDIR="$2"; shift 2;;
  '--sdkroot')
   if [[ -v BUILDS_SDKROOT ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_SDKROOT="$2"; shift 2;;
  '--minversion')
   if [[ -v BUILDS_MINVERSION ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_MINVERSION="$2"; shift 2;;
  '--jobs')
   if [[ -v BUILDS_JOBS ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_JOBS="$2"; shift 2;;
  '--checks')
   if [[ -v BUILDS_CHECKS ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   BUILDS_CHECKS="$2"; shift 2;;
  *) echo "\"$1\" is not supported!" >&2; exit 1;;
 esac
done

if [[ -v BUILDS_PUBLIC_KEY ]]; then
 if [[ -L "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is a symlink!" >&2; exit 1
 elif [[ ! -e "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" does not exist!" >&2; exit 1
 elif [[ ! -f "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is not a file!" >&2; exit 1
 elif [[ ! -s "${BUILDS_PUBLIC_KEY}" ]]; then
  echo "\"${BUILDS_PUBLIC_KEY}\" is empty!" >&2; exit 1
 fi
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

if [[ -v BUILDS_MINVERSION ]]; then
 if [[ -z "${BUILDS_MINVERSION}" ]]; then
  echo 'No minversion!' >&2; exit 1; fi
else
 BUILDS_MINVERSION='14.0'
fi


if [[ "${BUILDS_JOBS}" == 'max' ]]; then
 BUILDS_JOBS="$(sysctl -n hw.ncpu)"
 if [[ $? != 0 ]]; then
  echo 'Get jobs error!' >&2; exit 1; fi
elif [[ -v BUILDS_JOBS ]]; then
 if [[ -z "${BUILDS_JOBS}" ]]; then
  echo 'No jobs!' >&2; exit 1; fi
else
 BUILDS_JOBS=1
fi

if [[ ! "${BUILDS_JOBS}" =~ ^[1-9][0-9]?$ ]]; then
 echo 'Wrong jobs!' >&2; exit 1; fi

[[ ! -v BUILDS_CHECKS ]] && BUILDS_CHECKS='false'

case "${BUILDS_CHECKS}" in
 'false'|'true');;
 *) echo 'Wrong checks!' >&2; exit 1;;
esac

BUILDS_SUBJECT='gnupg'
BUILDS_ARCH='arm64'

#

if [[ ! -v BUILDS_SDKROOT ]]; then
 BUILDS_SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
 if [[ $? != 0 ]]; then
  echo 'Get sdk root error!' >&2; exit 1; fi
fi

if [[ -z "${BUILDS_SDKROOT}" ]]; then
 echo 'No sdk root!' >&2; exit 1
elif [[ ! -e "${BUILDS_SDKROOT}" ]]; then
 echo "\"${BUILDS_SDKROOT}\" does not exist!" >&2; exit 1
elif [[ ! -d "${BUILDS_SDKROOT}" ]]; then
 echo "\"${BUILDS_SDKROOT}\" is not a dir!" >&2; exit 1
fi

#

SUBJECTS=(
 'libgpg-error' '1.61'
 'libgcrypt' '1.12.4'
 'libassuan' '3.0.2'
 'libksba' '1.8.1'
 'npth' '1.8'
 "${BUILDS_SUBJECT}" "${BUILDS_VERSION}"
)

#

for ((i = 0; i < ${#SUBJECTS[@]}; i+=2)); do
 SUBJECT="${SUBJECTS[i]}-${SUBJECTS[i+1]}-sources.tar.bz2"
 rm "${BUILDS_WORKDIR}/${SUBJECT}"

 HTTP_CODE=$(curl -m 32 -w '%{http_code}' \
  --url "https://${BUILDS_SUBJECT}.org/ftp/gcrypt/${SUBJECTS[i]}/${SUBJECTS[i]}-${SUBJECTS[i+1]}.tar.bz2" \
  -o "${BUILDS_WORKDIR}/${SUBJECT}")

 if [[ $? -ne 0 ]]; then
  echo "Request \"${SUBJECT}\" error!" >&2; exit 1
 elif [[ "${HTTP_CODE}" != '200' ]]; then
  echo "Response \"${SUBJECT}\" error!" >&2; exit 1
 fi
done

#

if [[ -v BUILDS_PUBLIC_KEY ]]; then
 for ((i = 0; i < ${#SUBJECTS[@]}; i+=2)); do
  SUBJECT="${SUBJECTS[i]}-${SUBJECTS[i+1]}-sources.tar.bz2.sig"
  rm "${BUILDS_WORKDIR}/${SUBJECT}"
  HTTP_CODE=$(curl -m 32 -w '%{http_code}' \
   --url "https://${BUILDS_SUBJECT}.org/ftp/gcrypt/${SUBJECTS[i]}/${SUBJECTS[i]}-${SUBJECTS[i+1]}.tar.bz2.sig" \
   -o "${BUILDS_WORKDIR}/${SUBJECT}")
  if [[ $? -ne 0 ]]; then
   echo "Request \"${SUBJECT}\" error!" >&2; exit 1
  elif [[ "${HTTP_CODE}" != '200' ]]; then
   echo "Response \"${SUBJECT}\" error!" >&2; exit 1
  fi
  GPG_HOMEDIR="$(mktemp -d)"
  gpg --homedir "${GPG_HOMEDIR}" --no-default-keyring --keyring "${BUILDS_PUBLIC_KEY}" \
   --verify "${BUILDS_WORKDIR}/${SUBJECT}" \
   "${BUILDS_WORKDIR}/${SUBJECTS[i]}-${SUBJECTS[i+1]}-sources.tar.bz2"
  if [[ $? != 0 ]]; then echo "Verify ${SUBJECTS[i]}-${SUBJECTS[i+1]} error!" >&2; exit 1; fi
  rm "${BUILDS_WORKDIR}/${SUBJECT}"
  rm -rf "${GPG_HOMEDIR}"
 done
fi

#

mkdir -p "${BUILDS_WORKDIR}/sources/"
for ((i = 0; i < ${#SUBJECTS[@]}; i+=2)); do
 rm -rf "${BUILDS_WORKDIR}/sources/${SUBJECTS[i]}-${SUBJECTS[i+1]}/"
 tar -xf "${BUILDS_WORKDIR}/${SUBJECTS[i]}-${SUBJECTS[i+1]}-sources.tar.bz2" \
  -C "${BUILDS_WORKDIR}/sources/"
 if [[ $? != 0 ]]; then
  echo "Untar ${SUBJECTS[i]}-${SUBJECTS[i+1]} error!" >&2; exit 1; fi
 rm "${BUILDS_WORKDIR}/${SUBJECTS[i]}-${SUBJECTS[i+1]}-sources.tar.bz2"
done

#

rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/bin/"
:> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"
for ((i = 0; i < ${#SUBJECTS[@]}; i+=2)); do
 TIME_START="$(date +%s%3N)"
 CONFIGURE_ARGS=("--prefix=${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/")
 [[ "${SUBJECTS[i]}" == 'libgcrypt' ]] && CONFIGURE_ARGS+=('--disable-asm')
 [[ "${SUBJECTS[i]}" != "${BUILDS_SUBJECT}" ]] && CONFIGURE_ARGS+=('--enable-static' '--disable-shared')
 (set -x; cd "${BUILDS_WORKDIR}/sources/${SUBJECTS[i]}-${SUBJECTS[i+1]}/" \
  && CC='/usr/bin/clang' \
   CXX='/usr/bin/clang++' \
   CFLAGS="-O3 -arch ${BUILDS_ARCH} -mcpu=apple-m1 -mmacos-version-min=${BUILDS_MINVERSION}" \
   CPPFLAGS="-isysroot ${BUILDS_SDKROOT}" \
   LDFLAGS="-isysroot ${BUILDS_SDKROOT} -mmacos-version-min=${BUILDS_MINVERSION}" \
   PATH="${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/bin:${PATH}" \
   ./configure "${CONFIGURE_ARGS[@]}")
 if [[ $? != 0 ]]; then echo "Configure ${SUBJECTS[i]}-${SUBJECTS[i+1]} error!" >&2; exit 1; fi
 TIME_NOW="$(date +%s%3N)"
 echo "Configure ${SUBJECTS[i]}-${SUBJECTS[i+1]} $(((TIME_NOW - TIME_START) / 1000))s" \
  >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"
 #
 TIME_START="$(date +%s%3N)"
 (set -x; cd "${BUILDS_WORKDIR}/sources/${SUBJECTS[i]}-${SUBJECTS[i+1]}/" && make "-j${BUILDS_JOBS}")
 if [[ $? != 0 ]]; then echo "Make ${SUBJECTS[i]}-${SUBJECTS[i+1]} error!" >&2; exit 1; fi
 TIME_NOW="$(date +%s%3N)"
 echo "Make ${SUBJECTS[i]}-${SUBJECTS[i+1]} $(((TIME_NOW - TIME_START) / 1000))s" \
  >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"
 #
 if [[ "${BUILDS_CHECKS}" == 'true' ]]; then
  TIME_START="$(date +%s%3N)"
  (set -x; cd "${BUILDS_WORKDIR}/sources/${SUBJECTS[i]}-${SUBJECTS[i+1]}/" && make check)
  if [[ $? != 0 ]]; then echo "Check ${SUBJECTS[i]}-${SUBJECTS[i+1]} error!" >&2; exit 1; fi
  TIME_NOW="$(date +%s%3N)"
  echo "Check ${SUBJECTS[i]}-${SUBJECTS[i+1]} $(((TIME_NOW - TIME_START) / 1000))s" \
   >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"
 fi
 #
 (set -x; cd "${BUILDS_WORKDIR}/sources/${SUBJECTS[i]}-${SUBJECTS[i+1]}/" && make install)
 if [[ $? != 0 ]]; then echo "Install ${SUBJECTS[i]}-${SUBJECTS[i+1]} error!" >&2; exit 1; fi
done

#

BUILDS_SUFFIX="macos-${BUILDS_MINVERSION}-${BUILDS_ARCH}"
[[ ! -v BUILDS_PUBLIC_KEY ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-untrusted"
[[ "${BUILDS_CHECKS}" != 'true' ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-unchecked"

rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz"

(set -x; cd "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && tar -czf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz" .)

if [[ $? != 0 ]]; then
 echo "Tar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
