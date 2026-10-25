#!/usr/local/bin/bash

unset BUILDS_PUBLIC_KEY
unset BUILDS_VERSION
unset BUILDS_WORKDIR
unset BUILDS_SDKROOT
unset BUILDS_MINVERSION
unset BUILDS_JOBS

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

if [[ -v BUILDS_PUBLIC_KEY ]]; then
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
 gzip -dk "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar"
 if [[ $? != 0 ]]; then echo "Gzip ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 GPG_HOMEDIR="$(mktemp -d)"
 gpg --homedir "${GPG_HOMEDIR}" --no-default-keyring --keyring "${BUILDS_PUBLIC_KEY}" \
  --verify "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.sig" \
  "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar"

 if [[ $? != 0 ]]; then echo "Verify ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi
 rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.sig"
 rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar"
 rm -rf "${GPG_HOMEDIR}"
fi

#

rm -rf "${BUILDS_WORKDIR}/sources/${BUILDS_SUBJECT}-${BUILDS_VERSION}/"
mkdir -p "${BUILDS_WORKDIR}/sources/"

tar -xf "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz" \
 -C "${BUILDS_WORKDIR}/sources/"

if [[ $? != 0 ]]; then
 echo "Untar ${BUILDS_SUBJECT}-${BUILDS_VERSION} error!" >&2; exit 1; fi

rm "${BUILDS_WORKDIR}/${BUILDS_SUBJECT}-${BUILDS_VERSION}-sources.tar.gz"

#

echo 'Not implemented!' >&2; exit 1 # todo
