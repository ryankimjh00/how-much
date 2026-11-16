# 클러스터 배포

이 저장소의 `deploy/kubernetes`만 배포한다. `monithub-kubernetes`, `platform`에는 이슈·PR·커밋을 만들지 않는다.

## 구성

- namespace `howmuch`, FastAPI 1개·PostgreSQL 1개
- 운영 PVC `postgres-data-ryzen`: **2Gi**, `howmuch-local`, Ryzen SSD `/data/k8s/howmuch/postgres`, Retain
- 기존 Longhorn PVC `postgres-data`는 2026-11-17 이전 시점 복구용으로 보존한다. 현재 운영 쓰기는 반영되지 않는다.
- DB CPU 100m/500m, 메모리 128Mi/384Mi. API CPU 100m/500m, 메모리 64Mi/256Mi
- DB는 `worker-ryzen`에 고정하며 정확한 `monithub.io/dedicated=ci-ml:NoSchedule` toleration을 사용한다. Ryzen에는 Longhorn CSI가 없다.
- DB는 ClusterIP만 사용하며 API Pod만 5432 포트로 접근한다.
- API는 ingress Pod와 Cilium의 `remote-node` 트래픽에 8000 포트를 연다. hostNetwork 게이트웨이는 노드 출처로 식별되므로 신뢰하는 클러스터 노드도 접근 가능하다. 다른 일반 Pod는 허용하지 않는다.
- 전용 Gateway·VirtualService·인증서로 `howmuch.monithub.org`를 제공한다. 인증서와 Gateway는 `istio-ingress`에 새로 추가한다. 기존 공용 Gateway는 수정하지 않는다.
- cert-manager `letsencrypt-cloudflare` ClusterIssuer와 기존 wildcard DNS를 사용한다. 전용 인증서로 다른 호스트와의 HTTP/2 연결 재사용 문제를 피한다.

## 최초 배포

현재 클러스터에는 배포된 상태다. 재배포 때 기존 Secret과 두 PVC를 유지한다. 새 Ryzen 노드에는 먼저 `/data/k8s/howmuch/postgres`를 UID/GID 70, 권한 0700으로 준비한다. 노드 이름만 바꾸면 로컬 데이터가 따라가지 않는다.

```sh
kubectl config current-context
kubectl apply -f deploy/kubernetes/namespace.yaml
python3 deploy/create_db_secret.py
kubectl apply --dry-run=server -k deploy/kubernetes
kubectl apply -k deploy/kubernetes
kubectl -n howmuch rollout status statefulset/postgres --timeout=120s
kubectl -n howmuch rollout status deployment/api --timeout=120s
curl --fail https://howmuch.monithub.org/ready
```

`create_db_secret.py`는 기존 Secret을 바꾸지 않는다. 새 DB에만 관리자와 제한된 API 역할을 초기화한다. API 역할은 superuser·DB/role 생성 권한이 없다. 기존 볼륨에서 비밀번호를 바꾸려면 먼저 PostgreSQL 역할의 비밀번호를 변경한 뒤 Secret을 갱신해야 한다.

이미지는 Harbor 비공개 프로젝트 `howmuch`에 둔다. 배포용 `howmuch-pull` robot은 이 프로젝트의 pull 권한만 갖고, 자격 증명은 `howmuch/registry-credentials` Secret에 보관한다. 365일 만료 전에 Harbor에서 교체해야 한다. 빌드할 때는 같은 프로젝트의 임시 push robot을 사용하고 작업 후 폐기한다. 자격 증명을 저장소·명령 인수·로그에 넣지 않는다.

```sh
docker build -t registry.monithub.org/howmuch/api:<고유-태그> server
# Docker의 안전한 로그인 또는 임시 DOCKER_CONFIG로 인증한 뒤 실행한다.
docker push registry.monithub.org/howmuch/api:<고유-태그>
# 출력 digest로 api.yaml의 image를 갱신하고 배포한다.
```

Argo CD와 연결하지 않은 수동 배포다. 이 저장소에서 변경 후 `kubectl apply -k`를 실행한다. `delete -k`는 DB PVC도 지우므로 철거 명령으로 사용하지 않는다. API 롤백은 `api.yaml`의 이전 이미지 digest를 적용한다.

## 보존·백업·확장

단일 DB·Ryzen 로컬 SSD는 고가용성이 아니며 자동 백업은 아직 없다. PVC를 삭제하지 않는다. Retain은 백업을 대신하지 않는다. Ryzen 장애 시 별도 노드의 새 볼륨에 논리 백업을 복원해야 한다.

수동 백업은 접근을 제한한 폴더에 저장한다.

```sh
umask 077
kubectl -n howmuch exec postgres-0 -- pg_dump -U howmuch -d howmuch -Fc > howmuch.dump
```

복구는 동일한 Secret의 초기화 SQL로 API 역할을 만든 빈 PostgreSQL 17 DB에 `pg_restore --exit-on-error --single-transaction`으로 수행한다. 소유자와 ACL을 보존하고 API 역할의 접근을 검증한 뒤 운영 전환한다. 앱의 기록과 인증 해시가 포함되므로 백업 파일도 안전하게 관리한다. 볼륨 사용량은 다음으로 확인한다.

```sh
kubectl -n howmuch exec postgres-0 -- df -h /var/lib/postgresql/data
kubectl -n howmuch exec postgres-0 -- psql -U howmuch -d howmuch -c "SELECT pg_size_pretty(pg_database_size('howmuch'));"
```

WAL 목표 크기 256MiB와 Local PV의 2Gi 표기는 실제 디스크 사용의 절대 상한이 아니다. 로컬 PV 용량 변경만으로 디스크 quota가 적용되거나 확장되지 않는다. Ryzen SSD 여유 공간과 DB 크기를 함께 확인한다.

## 2026-11-17 Ryzen 이전

- [Issue #25](https://github.com/ryankimjh00/how-much/issues/25), 사용자 요청에 따라 PR 없이 진행한다.
- 같은 PostgreSQL 17.11 이미지의 ARM64→AMD64 전환이므로 데이터 디렉터리를 복사하지 않고 `pg_dump -Fc`와 `pg_restore`를 사용한다.
- 새 볼륨에서 복원을 사전 검증한 뒤 API를 0개로 내려 쓰기를 중단한다. 최종 dump 복원 후 모든 사용자 테이블의 행 수·데이터 지문을 비교하고 StatefulSet을 전환한다.
- 전환 후 `/ready`, 제한된 API DB 역할의 실제 연결, 운영 PVC와 Service endpoint를 확인한다.
- 운영 검증 완료: `postgres-0`은 `worker-ryzen`에서 1/1 Ready다. 3개 테이블의 행 수·데이터 지문이 이전 전후 일치했고, 제한된 API 역할의 DB 연결과 공개 `/ready` 200을 확인했다.
- 전환 후 롤백이 필요하면 API 쓰기를 중단하고 Ryzen의 최신 dump부터 확보한다. 기존 Longhorn PVC로 바로 돌아가면 전환 이후 쓰기가 누락된다.

## 실제 연결 검증

```sh
cd server
uv run python smoke_cluster.py
```

이 검사는 시험 계정만 만들며 **PostgreSQL을 재시작한다**. 사용자 접속이 적을 때 실행한다. 인증·복원·계정 분리·충돌·재시작 후 보존·Swagger·기존 홈페이지를 확인하고 이번 실행의 시험 계정을 지운다.
