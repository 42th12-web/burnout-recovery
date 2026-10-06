# Supabase 익명 인증 · RLS 검증 결과

검증일: 2026-09-29

## 검증 방법

1. 브라우저에서 `index.html`을 새로 열어 `signInAnonymously()`로 익명 로그인 (사용자 A).
2. `createTask()`로 `tasks`에 행을 insert하고, 응답값이 아니라 별도 `select`로 다시 조회.
3. 같은 페이지 안에 인증 저장소를 분리한 두 번째 Supabase 클라이언트를 만들어 익명 로그인 (사용자 B).
4. 사용자 B가 사용자 A의 행을 `select` / `delete` 시도.
5. 사용자 A가 자신의 행을 `delete`해서 테스트 데이터 정리.

## 결과

| 시도 | 수행자 | 결과 |
|---|---|---|
| insert 후 재조회 | 소유자(A) | 행 저장 확인, `user_id`가 A의 uid와 일치 |
| select | 다른 사용자(B) | 0건 (에러 없이 필터링) |
| delete | 다른 사용자(B) | 0행 삭제, 소유자 쪽에서 행이 그대로 존재 |
| delete | 소유자(A) | 정상 삭제 |

## 결론

- 익명 로그인 → `user_id` 자동 입력 → `tasks` insert/select가 실제 DB에서 동작한다.
- `tasks`의 RLS(`auth.uid() = user_id`)가 다른 사용자의 조회와 삭제를 막는다.
- 이번 검증 범위는 `tasks` 테이블뿐이다. `micro_tasks`, `sessions`, `snapshots`, `user_stats`의 정책은 아직 직접 검증하지 않았다.
- 1번 화면 입력과 체크리스트의 Supabase 연결은 아직 구현 전이며, 다음 차시에 진행한다.
