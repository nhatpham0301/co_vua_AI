# BE Bo Sung API - Thu Thap Du Lieu Cho AI

Muc tieu:
- Bo sung hop dong API phuc vu data pipeline cho huan luyen AI.
- Tach biet ro voi luong gameplay online dang co.

Ly do can bo sung:
- `doc/API.md` da co API gameplay online (`/api/games`, `/api/games/:id/moves`, ...).
- Chua co endpoint chuyen biet de thu thap, version, va export dataset cho huan luyen AI.

## 1) Event-level training data

### POST `/api/ai/training-events` (Auth: service token hoac user token)

Dung de ghi event theo tung nuoc di va context tai thoi diem do.

Request body de xuat:
```json
{
  "gameId": "aaaa1111-0000-0000-0000-000000000001",
  "moveNumber": 12,
  "sideToMove": "white",
  "fenBefore": "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  "candidateMove": {
    "from": "g1",
    "to": "f3",
    "promotion": null
  },
  "san": "Nf3",
  "clock": {
    "whiteMs": 294200,
    "blackMs": 298150
  },
  "source": "human_online",
  "metadata": {
    "timeControl": "blitz_5",
    "client": "ios",
    "appVersion": "1.0.2+3"
  }
}
```

Response:
```json
{ "accepted": true, "eventId": "evt-uuid" }
```

## 2) Game-level training sample

### POST `/api/ai/training-games` (Auth: service token)

Ghi full sample sau khi ket thuc van de phuc vu supervised training.

Request body de xuat:
```json
{
  "gameId": "aaaa1111-0000-0000-0000-000000000001",
  "result": "white",
  "termination": "checkmate",
  "timeControl": "blitz_5",
  "isRated": true,
  "whiteElo": 1342,
  "blackElo": 1318,
  "pgn": "[Event \"Online\"] ...",
  "moves": [
    {
      "moveNumber": 1,
      "from": "e2",
      "to": "e4",
      "san": "e4",
      "fenAfter": "..."
    }
  ],
  "labels": {
    "quality": "human_verified",
    "openingCode": "C20"
  }
}
```

Response:
```json
{ "accepted": true, "sampleId": "sample-uuid" }
```

## 3) Dataset export API

### GET `/api/ai/datasets/export`

Query params de xuat:
- `from` (ISO datetime)
- `to` (ISO datetime)
- `minElo` (optional)
- `maxElo` (optional)
- `format` (`jsonl` | `parquet`)

Response:
```json
{
  "jobId": "job-uuid",
  "status": "queued"
}
```

### GET `/api/ai/datasets/export/:jobId`

Response:
```json
{
  "jobId": "job-uuid",
  "status": "completed",
  "downloadUrl": "https://.../dataset.parquet",
  "expiresAt": "2026-04-12T10:00:00.000Z"
}
```

## 4) Data quality va moderation

### POST `/api/ai/training-flags`

Danh dau sample co van de (cheat, toxic chat, outlier time).

Request body de xuat:
```json
{
  "sampleId": "sample-uuid",
  "flag": "suspected_cheating",
  "note": "engine-like move sequence"
}
```

## 5) Bao mat va governance

- Tach quyen:
  - Client app chi duoc push event thiet yeu.
  - Export va quan tri dataset chi cho service/admin roles.
- PII:
  - Khong xuat email, IP trong dataset training.
  - User ID nen duoc hash/anon trong export cho research.
- Versioning:
  - Them `schemaVersion` cho moi ban ghi event/sample.

## 6) De xuat rollout

1. MVP:
- `POST /api/ai/training-events`
- `POST /api/ai/training-games`

2. Sau MVP:
- Export async (`/export`, `/export/:jobId`)
- Flagging quality (`/training-flags`)

3. Production:
- Data validation + deduplicate
- Monitoring throughput + dead-letter queue
