# 릴리스 안내

Coffee Time은 GitHub Releases에 DMG, 자동 업데이트용 ZIP, 서명된 `appcast.xml`, `SHA256SUMS.txt`를 함께 올립니다. 앱은 최신 정식 릴리스의 `appcast.xml`을 확인합니다.

## 다음 버전 배포하기

1. `Resources/Info.plist`의 `CFBundleShortVersionString`과 `CFBundleVersion`을 올리세요. 빌드 번호는 이전보다 커야 합니다.
2. `CHANGELOG.md`를 갱신하고 `docs/releases/버전.md`에 변경 사항을 작성하세요.
3. `./scripts/build.sh`와 `./scripts/test.sh`를 실행하세요.
4. 변경 사항을 Signed-off-by가 포함된 커밋으로 올리고 버전 태그를 푸시하세요.

```sh
git add .
git commit -s
git push origin main
git tag v1.1.1
git push origin v1.1.1
```

위 명령은 1.1.1을 배포하는 예입니다. 태그와 Info.plist의 버전은 같아야 합니다.

`Publish release` 워크플로가 빌드와 테스트를 마친 뒤 업데이트에 서명하고 GitHub 릴리스를 게시합니다. GitHub에서 릴리스를 직접 게시하거나 Actions에서 태그를 지정해 수동으로 실행할 수도 있습니다. 파일이 이미 모두 올라간 정식 릴리스는 다시 만들지 않습니다. 파일 일부만 올라간 경우에는 기존 파일을 확인하도록 작업을 중단합니다.

정식 배포는 태그를 푸시하는 방법을 권장합니다. 이 경우 파일을 모두 준비한 다음 초안을 공개하므로 업데이트 목록이 비어 있는 시간이 생기지 않습니다. 저장소에서 불변 릴리스를 사용한다면 공개 후 파일을 추가할 수 없으므로 반드시 이 방법을 사용하세요.

## 업데이트 서명 키

이 저장소의 GitHub Actions에는 `SPARKLE_PRIVATE_KEY`라는 암호화된 저장소 시크릿이 필요합니다. 앱에는 그 키의 공개 키만 `SUPublicEDKey`로 넣습니다. 개인 키를 소스, 릴리스 파일, 로그에 넣으면 안 됩니다.

로컬 배포에서는 Sparkle의 `generate_keys --account coffee-time`으로 만든 키체인 키를 사용합니다. 다른 Mac으로 옮길 때는 Sparkle의 키 내보내기와 가져오기 도구를 사용하고, 옮긴 파일은 안전하게 보관하세요. 이 키를 잃어버리면 기존 사용자에게 같은 신뢰 관계로 업데이트를 배포할 수 없게 됩니다.

새 키를 만들었다면 공개 키와 GitHub 시크릿을 함께 설정해야 합니다. 이미 배포한 앱의 키를 교체할 때는 Sparkle의 키 교체 절차를 먼저 확인하세요.

## 로컬에서 패키지 만들기

```sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/package-release.py
```

파일은 `dist/release-버전`에 생성됩니다. 패키지 스크립트는 앱의 코드 서명, 업데이트 ZIP의 서명, 업데이트 목록의 서명을 검사합니다. 서명된 목록을 수정했다면 다시 생성해야 합니다.

직접 게시하려면 GitHub CLI에 로그인하고 해당 태그를 먼저 푸시한 뒤 다음 명령을 실행하세요.

```sh
./scripts/publish-release.sh v1.1.0
```

## macOS 배포 서명

Sparkle의 업데이트 서명과 Apple의 Developer ID 서명은 서로 다릅니다. 현재 빌드는 로컬 코드 서명과 Sparkle 업데이트 서명을 사용하며, Apple 공증은 받지 않습니다.

Developer ID 배포 인증서를 준비하면 앱과 포함된 실행 파일에 배포 서명을 하고 공증을 받는 단계를 추가할 수 있습니다. 그 전까지는 첫 설치 때 macOS가 앱 실행을 차단할 수 있다는 안내를 유지해야 합니다.
