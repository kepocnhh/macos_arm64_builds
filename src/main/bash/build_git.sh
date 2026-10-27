#!/usr/local/bin/bash

unset BUILDS_PUBLIC_KEYS
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
   BUILDS_PUBLIC_KEYS+=("$2"); shift 2;;
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

if [[ -v BUILDS_CHECKS ]]; then
 case "${BUILDS_CHECKS}" in
  'false'|'true');;
  '') echo 'No checks!' >&2; exit 1;;
  *) echo 'Wrong checks!' >&2; exit 1;;
 esac
else
 BUILDS_CHECKS='false'
fi

BUILDS_SUBJECT='git'
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

SUBJECT="${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"
rm "${BUILDS_WORKDIR}/${SUBJECT}"

HTTP_CODE=$(curl -m 32 -w '%{http_code}' \
 --url "https://kernel.org/pub/software/scm/${BUILDS_SUBJECT}/${BUILDS_SUBJECT}-${BUILDS_VERSION}.tar.gz" \
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
  --url "https://kernel.org/pub/software/scm/${BUILDS_SUBJECT}/${BUILDS_SUBJECT}-${BUILDS_VERSION}.tar.sign" \
  -o "${BUILDS_WORKDIR}/${SUBJECT}")

 if [[ $? -ne 0 ]]; then
  echo "Request \"${SUBJECT}\" error!" >&2; exit 1
 elif [[ "${HTTP_CODE}" != '200' ]]; then
  echo "Response \"${SUBJECT}\" error!" >&2; exit 1
 fi

 rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar"
 gzip -dk "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"
 if [[ $? != 0 ]]; then echo "Gzip ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 GPG_HOMEDIR="$(mktemp -d)"
 GPG_ARGS=('--homedir' "${GPG_HOMEDIR}" '--no-default-keyring')
 for BUILDS_PUBLIC_KEY in "${BUILDS_PUBLIC_KEYS[@]}"; do GPG_ARGS+=('--keyring' "${BUILDS_PUBLIC_KEY}"); done
 GPG_ARGS+=('--verify' "${BUILDS_WORKDIR}/${SUBJECT}" "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar")
 gpg "${GPG_ARGS[@]}"
 if [[ $? != 0 ]]; then echo "Verify ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.sig"
 rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar"
 rm -rf "${GPG_HOMEDIR}"
fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/sources/"
tar -xf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz" -C "${BUILDS_WORKDIR}/sources/"
if [[ $? != 0 ]]; then echo "Untar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"

#

rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/bin/"
:> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"

#

TIME_START="$(date +%s%3N)"
(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && CC='/usr/bin/clang' \
  CFLAGS="-O3 -arch ${BUILDS_ARCH} -mcpu=apple-m1 -mmacos-version-min=${BUILDS_MINVERSION}" \
  CPPFLAGS="-isysroot ${BUILDS_SDKROOT}" \
  LDFLAGS="-isysroot ${BUILDS_SDKROOT} -mmacos-version-min=${BUILDS_MINVERSION}" \
  ./configure --prefix='/usr' --sysconfdir='/etc')
if [[ $? != 0 ]]; then echo "Configure ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
TIME_NOW="$(date +%s%3N)"
echo "Configure ${BUILDS_SUBJECT}-${BUILDS_VERSION} $(((TIME_NOW - TIME_START) / 1000))s" \
 >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"

#

BUILDS_PYTHON_SCRIPTS=()

TIME_START="$(date +%s%3N)"
(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && make RUNTIME_PREFIX=1 "-j${BUILDS_JOBS}" \
 SCRIPT_PYTHON="${BUILDS_PYTHON_SCRIPTS[*]}" NO_TCLTK=1 \
 sysconfdir='/etc' gitexecdir='libexec/git-core' template_dir='share/git-core/templates')
if [[ $? != 0 ]]; then echo "Make ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
TIME_NOW="$(date +%s%3N)"
echo "Make ${BUILDS_SUBJECT}-${BUILDS_VERSION} $(((TIME_NOW - TIME_START) / 1000))s" \
 >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"

TIME_START="$(date +%s%3N)"
(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/contrib/credential/osxkeychain/" \
 && make "-j${BUILDS_JOBS}" CC='/usr/bin/clang' \
 CFLAGS="-O3 -Wall -arch ${BUILDS_ARCH} -mcpu=apple-m1 -mmacos-version-min=${BUILDS_MINVERSION} -isysroot ${BUILDS_SDKROOT}" \
 LDFLAGS="-isysroot ${BUILDS_SDKROOT} -mmacos-version-min=${BUILDS_MINVERSION}")
if [[ $? != 0 ]]; then echo 'Make git-credential-osxkeychain error!' >&2; exit 1; fi
TIME_NOW="$(date +%s%3N)"
echo "Make git-credential-osxkeychain $(((TIME_NOW - TIME_START) / 1000))s" \
 >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"

#

if [[ "${BUILDS_CHECKS}" == 'true' ]]; then
 TIME_START="$(date +%s%3N)"
 (set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
  && make test RUNTIME_PREFIX=1 "-j${BUILDS_JOBS}" \
  SCRIPT_PYTHON="${BUILDS_PYTHON_SCRIPTS[*]}" NO_TCLTK=1 \
  sysconfdir='/etc' gitexecdir='libexec/git-core' template_dir='share/git-core/templates')
 if [[ $? != 0 ]]; then echo "Test ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 TIME_NOW="$(date +%s%3N)"
 echo "Test ${BUILDS_SUBJECT}-${BUILDS_VERSION} $(((TIME_NOW - TIME_START) / 1000))s" \
  >> "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-j${BUILDS_JOBS}.log"
fi

#

(set -x; cd "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 && make install RUNTIME_PREFIX=1 DESTDIR="${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/" \
 SCRIPT_PYTHON="${BUILDS_PYTHON_SCRIPTS[*]}" NO_TCLTK=1 \
 sysconfdir='/etc' gitexecdir='libexec/git-core' template_dir='share/git-core/templates')
if [[ $? != 0 ]]; then echo "Install ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

BUILDS_SRC="${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/contrib/credential/osxkeychain/git-credential-osxkeychain"
BUILDS_DST="${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/libexec/git-core/git-credential-osxkeychain"
cp "${BUILDS_SRC}" "${BUILDS_DST}"
if [[ $? != 0 ]]; then echo 'Install git-credential-osxkeychain error!' >&2; exit 1; fi

#

(set -x; cd "${BUILDS_WORKDIR}" \
 && "./bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/bin/${BUILDS_SUBJECT}" --version)
if [[ $? != 0 ]]; then echo "Get version ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

(set -x; cd "${BUILDS_WORKDIR}" \
 && "./bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/libexec/git-core/git-credential-osxkeychain" noop </dev/null)
if [[ $? != 0 ]]; then echo "Get version git-credential-osxkeychain error!" >&2; exit 1; fi

#

BUILDS_SUFFIX="macos-${BUILDS_MINVERSION}-${BUILDS_ARCH}"
[[ "${#BUILDS_PUBLIC_KEYS[@]}" -eq 0 ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-untrusted"
[[ "${BUILDS_CHECKS}" != 'true' ]] && BUILDS_SUFFIX="${BUILDS_SUFFIX}-unchecked"

rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz"
(set -x; cd "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/usr/" \
 && tar -czf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-${BUILDS_SUFFIX}.tar.gz" .)
if [[ $? != 0 ]]; then echo "Tar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
rm -rf "${BUILDS_WORKDIR}/bin/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
