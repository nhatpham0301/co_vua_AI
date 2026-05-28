# AI Level Progression API for Mobile

Tai lieu nay mo ta contract cua tinh nang tien trinh cap do AI (AI Level Progression) de mobile tich hop chinh xac.

## Tong quan

Moi user co mot truong `aiLevelUnlocked` (so nguyen, mac dinh = 1, toi da = 9).

- **Tu dong tang**: Server tu dong tang level khi user thang mot van vs AI.
- **Khong tu dong giam**: Server dung `GREATEST` — level chi tang, khong bao gio giam khi thua.
- **Manual set**: Co API de admin / dev test dat lai level tuy y.

---

## 1. Lay thong tin level hien tai

Tra ve trong profile cua user.

- **Method**: `GET`
- **Path**: `/api/users/me`
- **Auth**: Bat buoc (Bearer token)

### Response Shape

```json
{
  "id": "4bda237d-ca07-4293-91e5-2ccba12197a2",
  "username": "nhat0301",
  "avatarUrl": null,
  "elo": 1200,
  "gamesPlayed": 10,
  "aiLevelUnlocked": 3,
  "createdAt": "2026-05-01T00:00:00.000Z"
}
```

### Field `aiLevelUnlocked`

| Gia tri | Y nghia |
| --- | --- |
| `1` | Mac dinh — chi duoc choi cap 1 |
| `3` | Da thang cap 1 va cap 2, duoc choi cap 1 den cap 3 |
| `9` | Da mo khoa toan bo 9 cap do |

### Logic hien thi tren mobile (goi y)

```
level 1 .. aiLevelUnlocked  → cho phep chon (unlocked)
level aiLevelUnlocked+1 .. 9 → hien thi khoa (🔒)
```

---

## 2. Auto-unlock khi thang AI

Khong can goi API — server tu xu ly sau moi van dau.

**Dieu kien**:
- Van dau la Human vs AI (khong phai AI vs AI)
- User thang (result === mau cua user)

**Ket qua**:

| Thang cap | Level duoc mo |
| --- | --- |
| Cap 1 | Mo den cap 2 |
| Cap 2 | Mo den cap 3 |
| ... | ... |
| Cap 8 | Mo den cap 9 |
| Cap 9 | Giu nguyen cap 9 (max) |

Mobile chi can doc lai `aiLevelUnlocked` tu `GET /api/users/me` sau khi van ket thuc de render UI cap nhat.

---

## 3. Set level thu cong (admin / testing)

- **Method**: `PATCH`
- **Path**: `/api/users/me/ai-level`
- **Auth**: Bat buoc (Bearer token)

### Request Body

```json
{
  "aiLevelUnlocked": 5
}
```

| Field | Type | Bat buoc | Rang buoc |
| --- | --- | --- | --- |
| `aiLevelUnlocked` | integer | Co | 1 – 9 |

### Response Shape

```json
{
  "id": "4bda237d-ca07-4293-91e5-2ccba12197a2",
  "username": "nhat0301",
  "aiLevelUnlocked": 5
}
```

### Error Cases

| HTTP | Code | Mo ta |
| --- | --- | --- |
| `400` | `VALIDATION_ERROR` | `aiLevelUnlocked` khong phai so nguyen hoac ngoai khoang 1–9 |
| `401` | `UNAUTHORIZED` | Thieu hoac sai token |

### Vi du curl

```bash
curl -X PATCH https://giaitri.cloud/api/users/me/ai-level \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"aiLevelUnlocked": 5}'
```

> **Luu y**: Endpoint nay ghi de truc tiep (khong dung GREATEST), co the tang hoac giam tuy y. Chi dung cho admin / testing — khong expose tren UI nguoi dung.

---

## Luong tich hop tren mobile

```
1. User mo man hinh chon cap AI
   → GET /api/users/me
   → doc aiLevelUnlocked

2. Hien thi level 1..aiLevelUnlocked (co the chon)
   Hien thi level (aiLevelUnlocked+1)..9 (khoa, co the hien thi icon 🔒)

3. User choi xong van vs AI
   → Server tu dong cap nhat aiLevelUnlocked neu thang
   → Mobile goi lai GET /api/users/me de refresh
   → Re-render man hinh chon cap voi level moi (neu co)
```
