# 메일상자 인프라

MailSangja Kubernetes 클러스터의 GitOps desired state를 관리하는 매니페스트 저장소입니다.

이 저장소는 traefik을 사용하는 k3s 클러스터를 대상으로 하며, Argo CD App of Apps 패턴으로 플랫폼 구성요소와 메일상자 애플리케이션 워크로드를 배포합니다.

## 관리 대상

- Argo CD root/child `Application`
- cert-manager 및 Let's Encrypt `ClusterIssuer`
- Sealed Secrets controller
- Argo CD Ingress
- 메일상자 애플리케이션
  - 메일상자 Core 서버
  - 메일상자 worker 서버
  - PostgreSQL
  - Redis
  - RabbitMQ
  - Grafana, Loki, Tempo, Alloy
  - Ingress 및 TLS 설정

## 저장소 구조

| 경로 | 설명 |
| --- | --- |
| `bootstrap/` | 클러스터에 최초 1회 적용하는 root Argo CD `Application` |
| `argocd/applications/` | Argo CD child `Application` 선언 |
| `platform/` | 클러스터 공통 플랫폼 리소스 |
| `apps/` | 비즈니스 애플리케이션 워크로드 |
| `docs/` | 아키텍처와 릴리스 운영 문서 |
| `scripts/` | 운영 보조 스크립트 |

## Bootstrap

Argo CD가 설치된 클러스터에서 root `Application`을 1회 적용합니다.

```sh
kubectl apply -f bootstrap/root-app.yaml
```

이후 Argo CD가 `argocd/applications/` 아래의 child `Application`을 동기화합니다.

## Sync Wave

현재 배포 순서는 다음과 같습니다.

| Wave | Application | 역할 |
| --- | --- | --- |
| `0` | `cert-manager` | 인증서 controller |
| `0` | `sealed-secrets` | SealedSecret controller |
| `10` | `cert-manager-issuers` | Let's Encrypt ClusterIssuer |
| `20` | `argocd-ingress` | Argo CD 외부 접근 |
| `30` | 미사용 | observability, logging, policy 등 운영 플랫폼 |
| `40` | `mailsangja` | MailSangja 애플리케이션 |

파일명 prefix와 `argocd.argoproj.io/sync-wave` annotation을 함께 맞춥니다.

## 애플리케이션 변경

이미지 태그는 불변 태그를 사용합니다.

```text
ghcr.io/mailsangja/<image>:sha-<commit>
```

이미지 업데이트는 애플리케이션 CI가 이 저장소에 PR을 생성하는 방식으로 반영합니다. 애플리케이션 CI는 클러스터를 직접 수정하지 않습니다.

자세한 운영 기준은 [릴리즈와 이미지 업데이트 운영 문서](docs/release-management.md)를 참고합니다.

## Secret 관리

Secret 평문은 Git에 커밋하지 않습니다. Secret 변경은 SealedSecret으로 변환한 뒤 매니페스트만 커밋합니다.

```sh
scripts/seal-secret.sh \
  mailsangja \
  mailsangja-app-secret \
  /private/tmp/mailsangja-app.secret.env \
  apps/mailsangja/sealedsecret-app.yaml
```

원본 env 파일은 저장소 밖에 두거나 `*.secret.env` 형태로 관리합니다.

## 주요 문서

- [k3s GitOps 아키텍처](docs/architecture.md): GitOps 구조, 디렉터리 책임, App of Apps 운영 기준
- [릴리즈와 이미지 업데이트 운영](docs/release-management.md): 이미지 업데이트, 자동 PR, 설정 변경 순서, rollback 기준

## 운영 원칙

- 클러스터 desired state는 Git에 선언합니다.
- 수동 `kubectl patch`는 일회성 진단을 제외하고 사용하지 않습니다.
- rollback은 이전 이미지 태그나 이전 매니페스트로 되돌리는 Git 변경으로 수행합니다.
- Secret 평문, kubeconfig, 개인 인증 정보는 커밋하지 않습니다.
