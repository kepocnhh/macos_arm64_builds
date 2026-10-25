# macos_arm64_builds
macos arm64 builds

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

---
