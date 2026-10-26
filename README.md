# macos_arm64_builds
macos arm64 builds

---

#### build [make](https://ftp.gnu.org/gnu/make/)

```
./src/main/bash/build_make.sh --version "${MAKE_VERSION}" --public_key ./src/main/res/b250.gpg --public_key ./src/main/res/96b0.gpg
```

---

#### build [bash](https://ftp.gnu.org/gnu/bash/)

```
./src/main/bash/build_bash.sh --jobs max --version "${BASH_VERSION}" --public_key ./src/main/res/7c01.gpg
```

---

#### build [coreutils](https://ftp.gnu.org/gnu/coreutils/)

```
./src/main/bash/build_coreutils.sh --jobs max --version "${COREUTILS_VERSION}" --public_key ./src/main/res/6c37.gpg
```

---

#### build [tar](https://ftp.gnu.org/gnu/tar/)

```
./src/main/bash/build_tar.sh --jobs max --version "${TAR_VERSION}" --public_key ./src/main/res/325f.gpg
```

---

#### build [nano](https://ftp.gnu.org/gnu/nano/)

```
./src/main/bash/build_nano.sh --jobs max --version "${NANO_VERSION}" --public_key ./src/main/res/168e.gpg
```

---

#### build [xz](https://github.com/tukaani-project/xz/releases/)

```
./src/main/bash/build_xz.sh --jobs max --version "${XZ_VERSION}" --public_key ./src/main/res/3690.gpg
```

---

#### build [gnupg](https://gnupg.org/download/index.html)

```
./src/main/bash/build_gnupg.sh --version "${GNUPG_VERSION}" --jobs max --checks true --public_key ./src/main/res/ac8e.gpg --public_key ./src/main/res/6daa.gpg
```

---

#### build [git](https://kernel.org/pub/software/scm/git/)

```
./src/main/bash/build_git.sh --version "${GIT_VERSION}" --public_key ./src/main/res/e1f0.gpg
```

```
git config --global credential.helper /Applications/Xcode.app/Contents/Developer/usr/libexec/git-core/git-credential-osxkeychain
```

---

#### build [curl](https://curl.se/download/)

```
./src/main/bash/build_curl.sh --jobs max --version "${CURL_VERSION}" --public_key ./src/main/res/27ed.gpg --openssl_version "${OPENSSL_VERSION}" --public_key ./src/main/res/c46e.gpg --apple_sectrust true
```

---
