# 릴리스와 이미지 업데이트 운영

## 목적

이 문서는 애플리케이션 이미지가 빌드된 뒤 GitOps 저장소를 통해 클러스터에
반영되는 운영 흐름을 정의한다. 현재 기준은 단일 환경 운영이다. dev/prod 같은
환경 분리는 실제 운영 경계가 필요해질 때 별도로 확장한다.

## 기본 원칙

애플리케이션 소스 저장소와 GitOps 저장소의 책임을 분리한다.

- 애플리케이션 저장소는 테스트, 이미지 빌드, registry push를 책임진다.
- GitOps 저장소는 클러스터 desired state를 관리한다.
- 애플리케이션 CI는 클러스터를 직접 수정하지 않는다.
- 애플리케이션 CI는 GitOps 저장소에 이미지 태그 변경 PR만 생성한다.

이미지 태그는 불변 태그를 사용한다. 기본 형식은 애플리케이션 commit을 추적할 수
있는 `sha-<commit>`이다.

```text
ghcr.io/<org>/<image>:sha-<commit>
```

## 자동 PR 범위

애플리케이션 CI는 이미지가 빌드되고 registry에 push된 뒤 GitOps 저장소에 PR을
생성하거나 기존 PR을 갱신한다.

```text
app repository main merge
  -> test
  -> image build
  -> image push
  -> GitOps repository image tag PR 생성 또는 갱신
```

자동 PR은 다음 범위만 포함한다.

- 이미지 태그 변경
- 필요 시 이미지 digest pinning 변경
- 변경된 이미지와 commit을 설명하는 PR 본문 작성

다음 변경은 자동 PR에 포함하지 않는다.

- ConfigMap 변경
- SealedSecret 변경
- Ingress 또는 routing 변경
- DB, queue, storage 등 stateful 인프라 변경
- runtime contract가 바뀌는 Kubernetes manifest 변경

자동 PR은 자동 머지하지 않는다. 운영자는 PR diff와 애플리케이션 변경 내용을
확인한 뒤 머지한다.

## PR 브랜치 정책

자동 PR은 고정 source branch를 사용하고 `main`을 base branch로 한다.

```text
automation/<app-name> -> main
```

자동화 브랜치는 CI 전용이다. 사람은 `automation/*` 브랜치에 직접 커밋하지
않는다.

새 이미지가 생기면 CI는 최신 `main`을 기준으로 이미지 태그만 변경한 뒤 같은
automation branch를 갱신한다. 이 방식은 열린 PR 하나를 최신 배포 후보로
유지하기 위한 것이다.

자동 PR에 추가 설정 변경이 필요하다고 판단되면 다음 중 하나를 선택한다.

1. 호환 가능한 설정 변경을 별도 PR로 먼저 `main`에 반영한 뒤 자동 PR을 갱신한다.
2. 이미지 태그와 설정 변경을 원자적으로 묶어야 하면 자동 PR을 닫고 사람이 새
   PR로 대체한다.

## 설정 변경과 이미지 변경 순서

설정 변경은 가능한 한 새 이미지보다 먼저 반영할 수 있도록 작성한다. 기존 이미지가
무시할 수 있는 신규 env, Secret key, ConfigMap key 추가는 이미지 태그 변경보다
먼저 배포할 수 있다.

다음 변경은 기존 이미지와 호환되지 않을 수 있으므로 이미지 변경과 함께 별도 수동
PR로 묶어 검토한다.

- 기존 env 이름 변경 또는 삭제
- 기존 Secret key 삭제
- 기존 ConfigMap key 삭제
- 기존 앱이 처리하지 못하는 필수 설정 추가
- 새 앱 버전만 전제로 하는 routing 변경
- schema 또는 stateful resource의 비호환 변경

배포 순서는 기본적으로 다음을 따른다.

```text
호환 가능한 infra 변경
  -> 이미지 태그 변경 PR
  -> PR 머지
  -> Argo CD sync
  -> rollout과 ingress 응답 확인
```

## Rollback

배포 실패 시 rollback은 이전 이미지 태그로 되돌리는 Git 변경으로 수행한다.
클러스터에서 직접 image를 patch하는 방식은 일회성 진단을 제외하고 사용하지
않는다.
