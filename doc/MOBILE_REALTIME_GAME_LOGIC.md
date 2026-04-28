# Mobile Realtime Game Logic

## Muc dich

Tai lieu nay mo ta ro cac thay doi lien quan den nhap thanh de mobile ap dung dung voi backend hien tai.

Muc tieu chinh:

- Nhap thanh chi duoc coi la hop le khi nguoi choi chon quan vua
- Khong kich hoat nhap thanh khi nguoi choi chon quan xe
- Sau khi nhap thanh, mobile phai cap nhat dung ca vua va xe
- Sau moi nuoc di, mobile phai dong bo theo state tu server, khong suy luan bang local rule rieng
- Khi dang bi chieu, mobile co du thong tin de hien thi ro trang thai nay

## Tom tat thay doi backend

Backend da duoc chinh theo cac diem sau:

1. API legal moves tra ve thong tin ro hon cho o dang duoc chon
2. Nhap thanh chi xuat hien trong legal moves khi o dang chon la vua
3. Socket `game:move:ok` tra them thong tin `castling` de mobile biet xe da di tu dau den dau
4. `game:state` va `game:move:ok` tra them thong tin `check` va `checkMessage` de mobile hien thi trang thai dang bi chieu

## Nguyen tac bat buoc cho mobile

Mobile phai coi server la nguon su that duy nhat cho:

- nuoc di hop le
- board state sau moi nuoc di
- luot hien tai
- trang thai chieu
- dong ho

Mobile khong duoc tu viet logic dac biet cho nhap thanh theo kieu:

- bam vao xe de suy ra nhap thanh
- tu doi cho xe khi vua di ma khong can cu vao response server
- giu board state bang cach tu sua local chi dua tren `from` va `to`

## Luong dung cho mobile

### 1. Khi user bam vao mot quan

Mobile phai goi:

```http
GET /api/games/:id/legal-moves?from=<square>
Authorization: Bearer <token>
```

Vi du:

```http
GET /api/games/123/legal-moves?from=e1
```

### 2. Server tra ve legal moves

Response da co them metadata de mobile biet dang chon gi:

```json
{
  "from": "e1",
  "selectedPiece": {
    "type": "k",
    "color": "w"
  },
  "castlingSelectionEnabled": true,
  "moves": [
    { "to": "f1", "flags": "n", "promotion": null, "isCastle": false },
    { "to": "g1", "flags": "k", "promotion": null, "isCastle": true },
    { "to": "c1", "flags": "q", "promotion": null, "isCastle": true }
  ]
}
```

Y nghia:

- `selectedPiece`: quan dang duoc chon tren o `from`
- `castlingSelectionEnabled`: `true` chi khi dang chon vua
- `moves[].isCastle`: danh dau day la nuoc nhap thanh
- `moves[].flags`:
  - `k`: nhap thanh canh vua
  - `q`: nhap thanh canh hau
  - `n`: nuoc di binh thuong

### 3. Rule UI khi chon vua

Neu mobile goi `from=e1` hoac `from=e8` va response co:

- `castlingSelectionEnabled = true`
- co move co `isCastle = true`

thi mobile duoc hien thi cac o nhap thanh cho vua.

### 4. Rule UI khi chon xe

Neu mobile goi `from=h1`, `a1`, `h8`, `a8` thi backend van co the tra ve nuoc di binh thuong cua xe, vi do la move hop le cua xe.

Nhung:

- `castlingSelectionEnabled` se la `false`
- khong co move nao duoc coi la castle

Vi vay mobile tuyet doi khong duoc tu kich hoat nhap thanh khi user bam vao xe.

## Cach gui nuoc di nhap thanh

Nhap thanh van duoc gui nhu mot nuoc di cua vua:

### White

- kingside: `e1 -> g1`
- queenside: `e1 -> c1`

### Black

- kingside: `e8 -> g8`
- queenside: `e8 -> c8`

Request:

```http
POST /api/games/:id/moves
Content-Type: application/json
Authorization: Bearer <token>

{
  "from": "e1",
  "to": "g1"
}
```

Luu y:

- Mobile chi gui move cua vua
- Mobile khong gui them move rieng cho xe

## Socket sau khi di nuoc

Khi server chap nhan nuoc di, socket phat `game:move:ok`.

### Response mau khi nhap thanh

```json
{
  "gameId": "123",
  "from": "e1",
  "to": "g1",
  "promotion": null,
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/R4RK1 b kq - 1 1",
  "check": false,
  "checkMessage": null,
  "turn": "black",
  "clocks": {
    "white": 298.4,
    "black": 300
  },
  "castling": {
    "rookFrom": "h1",
    "rookTo": "f1"
  }
}
```

Y nghia cac field quan trong:

- `fen`: board state day du sau nuoc di
- `turn`: luot hien tai sau nuoc di
- `castling`: thong tin di chuyen cua xe khi day la nuoc nhap thanh
- `check`: ben sap di co dang bi chieu hay khong
- `checkMessage`: chuoi de mobile hien thi trang thai bi chieu
- `clocks`: dong ho authoritative tu server

## Cach mobile cap nhat board sau nuoc di

Thu tu dung:

1. Nhan `game:move:ok`
2. Cap nhat board theo `fen`
3. Cap nhat turn theo `turn`
4. Cap nhat clocks theo `clocks`
5. Neu `castling != null`, co the dung `rookFrom` va `rookTo` de animate xe
6. Neu `check = true`, hien thi UI dang bi chieu

Thu tu khong nen dung:

1. Tu di chuyen local piece bang `from` va `to`
2. Sau do moi sua lai bang `fen`

Cach sai nay rat de lam board lech trong cac truong hop:

- nhap thanh
- en passant
- promotion

## Hien thi trang thai dang bi chieu

Backend da bo sung du lieu de mobile hien thi trang thai nay on dinh hon.

### Trong `game:move:ok`

Neu nuoc vua di xong khien doi thu dang bi chieu:

```json
{
  "check": true,
  "checkMessage": "dang_bi_chieu"
}
```

### Trong `game:state`

Khi mobile join phong, reconnect, hoac vao xem tran dang choi, server cung co the tra:

```json
{
  "gameId": "123",
  "fen": "4k3/8/8/8/8/8/4Q3/4K3 b - - 0 1",
  "status": "in_progress",
  "check": true,
  "checkMessage": "dang_bi_chieu"
}
```

Dieu nay giup mobile hien thi dung ngay ca khi nguoi dung vao giua van co hoac vua reconnect.

## Logic mobile duoc de xuat

### Khi user chon o

1. Goi `GET /legal-moves?from=<square>`
2. Doc `selectedPiece`
3. Neu `selectedPiece.type == 'k'` va `castlingSelectionEnabled == true`, cho phep hien thi castle moves
4. Neu `selectedPiece.type != 'k'`, khong co logic dac biet cho nhap thanh

### Khi user chon nuoc di

1. Gui `POST /moves`
2. Cho response thanh cong hoac `game:move:ok`
3. Render lai board theo `fen`

### Khi nhan `game:state`

1. Render board theo `fen`
2. Hien thi clocks neu co
3. Neu `check = true`, hien thi trang thai dang bi chieu

### Khi nhan `game:move:ok`

1. Render lai board theo `fen`
2. Cap nhat turn
3. Cap nhat clocks
4. Doc `castling` de animate xe neu can
5. Doc `check` va `checkMessage` de hien thi trang thai chieu

## Checklist cho mobile dev

- Luon goi server de lay legal moves
- Khong suy ra castle khi bam vao xe
- Chi cho castle khi dang chon vua
- Gui castle nhu mot move cua vua
- Render board bang `fen`
- Dung `castling` de animate rook neu can
- Dung `turn` de khoa luot nguoi choi
- Dung `check` va `checkMessage` de hien thi dang bi chieu
- Dung `clocks` de dong bo dong ho

## Ket luan

Neu mobile lam dung theo tai lieu nay thi se tranh duoc cac loi sau:

- bam vao xe ma van hien thi nhap thanh
- vua nhap thanh xong nhung xe khong doi vi tri dung
- vua nhap thanh xong van bi lech luot va di tiep sai
- vao giua van co hoac reconnect nhung khong hien thi trang thai dang bi chieu