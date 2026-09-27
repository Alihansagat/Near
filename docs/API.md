# API v1

Base: `/api/`. JSON, кроме загрузки фото (`multipart/form-data`). Bearer JWT в заголовке Authorization. Ошибки в формате DRF; 400 — валидация, 401 — сессия, 403 — действие запрещено, 404 — объект отсутствует в текущей паре, 429 — лимит запросов.

| Метод | Путь | Данные / результат |
|---|---|---|
| POST | auth/register/ | email, password, full_name, time_zone (опционально) |
| POST | auth/token/ | email, password → access, refresh |
| POST | auth/refresh/ | refresh → новая пара токенов; старый refresh отзывается |
| POST | auth/logout/ | refresh → 204 |
| GET/PATCH | me/ | профиль; доступны full_name, avatar URL, mascot, mood, time_zone |
| GET/POST/PATCH | couple/ | получить / создать / изменить даты, distance_km, time_zone |
| POST | couple/join/ | invite_code; пользователь ещё не должен входить в пару |
| POST | couple/rotate-invite/ | новый invite_code |
| GET | home/ | couple, days_together, meeting, days_until_meeting + ежедневные данные |
| POST | daily/photo/ | multipart `photo`; только для текущего дня пары |
| POST | daily/answer/ | answer_text; вопрос текущего дня определяет сервер |
| GET | moments/?page=1 | count (дни), next (номер или null), results; 20 дней на страницу |
| GET/POST | dates/ | paginated список / создать: type, scheduled_at ISO-8601, note |
| GET | dates/{id}/ | свидание текущей пары |
| POST | dates/{id}/respond/ | status: accepted или declined |
| GET/POST | meetings/ | список / создать: target_date YYYY-MM-DD, title, location |
| GET/PATCH/DELETE | meetings/{id}/ | управление встречей текущей пары |

Ежедневные данные:

```json
{
  "day": "2026-09-22",
  "photo_prompt": "Your morning light",
  "photos": [{"id": 1, "user": 2, "day": "2026-09-22", "photo_url": null, "created_at": "2026-09-22T08:00:00Z"}],
  "photos_revealed": false,
  "question": {"id": 1, "question_text": "What made you smile today?", "category": "connection"},
  "answers": [{"id": 1, "question": 1, "user": 2, "answer_text": null, "created_at": "2026-09-22T08:00:00Z"}],
  "answers_revealed": false
}
```

Свои фото/ответы доступны сразу. Данные партнёра раскрываются, когда множество отправителей включает обоих участников пары. Один участник не удовлетворяет этому условию. Фото и ответы раскрываются независимо. Если контент на дату не подготовлен, question=null и endpoint ответа возвращает 404.

Дополнения к исходной схеме: `User.couple` для атомарного членства; `Couple.time_zone`, `distance_km`; `DailyPhotoSubmission.day`, приватное поле `photo` вместо сохранения публичного URL; `DailyQuestion.date`; `DailyAnswer.couple`. Это обеспечивает устойчивую привязку заданий и проверку доступа в архиве. В API сохранено поле `photo_url`.


## Near additions

- `GET /api/home/` adds nullable `days_apart` and `recent_photo_day` (latest daily photo payload with photos younger than 24 hours). Existing daily fields continue to represent the shared current day. `meeting` selects only `kind=meeting`.
- `/api/meetings/` adds `kind`: meeting (default), anniversary, birthday, trip, other.
- `/api/dates/` adds optional `detail` (200 characters), and coffee, music, quiz, talk, surprise activity types. Legacy types remain readable.
- `POST /api/dates/{id}/reschedule/` accepts future `scheduled_at`. Only the recipient of a pending, unexpired invitation can propose another time. The proposal changes creator to the proposer and remains pending, so the original sender must respond.
- Memory capsules group permanent `/api/moments/` records by shared calendar month; `GET /api/moments/?month=YYYY-MM` returns the complete selected month in chronological order (up to 31 days), independently of archive pagination.
# Маскоты и настроение

`GET /api/me/` и пользователи внутри `home.couple` включают `mascot` и `mood`.
`PATCH /api/me/` сохраняет выбор только текущего пользователя:

```json
{"mascot": "female", "mood": "anxious"}
```

`mascot`: `male`, `female` или пустая строка (образ по умолчанию).
`mood`: `joyful`, `loving`, `missing`, `anxious`, `sleepy`, `angry` или пустая строка (не делиться настроением).
Настроение сохраняется до следующего изменения. Партнёр видит обновление при обновлении Home или возвращении в приложение; push/realtime не добавлены.
Применить миграцию `0004_user_mascot_user_mood` перед запуском обновлённого сервера.


## Relationship features (6–10)

All routes below are under `/api/`, require JWT, and are scoped to the authenticated user's couple. Lists use the existing pagination contract (`count`, `next`, `previous`, `results`). Client-supplied couple, sender, and creator IDs do not select ownership.

| Route | Methods | Fields / behavior |
| --- | --- | --- |
| `me/` | GET, PATCH | Adds read-only `mood_day`; changing `mood` stamps the couple-local day. Optional `latitude`/`longitude` must be provided together, or both set to null. |
| `envelopes/` | GET, POST | `title`, `text`; multipart repeated `files` for up to 12 attachments. Requires text or at least one attachment. |
| `envelopes/{id}/` | GET | Full envelope with `creator`, `created_at`, and `attachments` (`id`, `kind`, `name`, `url`). |
| `story/` | GET, POST | `date`, `text`, optional `location`, `emoji` (defaults to ❤️), optional multipart `photo`. Ascending date and ID. Response includes protected `photo_url`. |
| `story/{id}/` | GET, PUT, PATCH, DELETE | Shared couple story entry. |
| `messages/` | GET, POST | `text`; sender and timestamp are assigned by the server. Newest first. Requires a connected partner. |
| `messages/hug/` | POST | Saves a message with exact text `🫂`. |
| `places/` | GET, POST | `title`, `latitude` [-90, 90], `longitude` [-180, 180]. |
| `places/{id}/` | GET, PUT, PATCH, DELETE | Shared memorable place. |
| `wishlist/` | GET, POST | `title`, `completed` (defaults to false). Uncompleted items first. |
| `wishlist/{id}/` | GET, PUT, PATCH, DELETE | Shared wish; PATCH `completed` to mark or undo completion. |
| `relationship-media/attachment/{id}/` | GET | Authenticated attachment delivery, including single byte ranges (`206`, `416`). |
| `relationship-media/story/{id}/` | GET | Authenticated story photo delivery. |

Mood keys shown by the picker: `joyful` = 😊 Happy, `loving` = 🥰 Loved, `sleepy` = 😴 Tired, `missing` = 🥹 Missing you, `sad` = 😔 Sad, `angry` = 😡 Angry. Existing `anxious` data remains readable for compatibility; it is not a new selectable option. Empty mood clears the check-in date.

Envelope photo extensions: jpg/jpeg/png/webp; video: mp4/mov/webm; audio: mp3/m4a/wav/ogg/aac. Each file is limited to 50 MB; story photos to 10 MB. Playback codec availability depends on the device. Files remain private with local or S3 storage; no public storage URL is exposed for these features. The mobile app calculates great-circle distance from both shared coordinate pairs, falling back to `couple.distance_km` when a pair is missing. Coordinates are entered manually, not collected in the background.


## Question category selection and countdown editing

- `POST /api/daily/question/category/` with `category` (`fun`, `deep`, `future`, `random`) selects the couple's shared question for today. Selection persists per couple and day; another couple is unaffected. Returns the daily payload.
- `question_category_locked` is true after either partner answers. Selecting another category then returns 400, preserving a single shared question and existing answers. Archives retain the selected text/category.
- `POST /api/daily/answer/` accepts optional `question_id` and `question_category` to reject an answer drafted before a partner changed the question. The mobile client sends both.
- `PATCH /api/meetings/{id}/` updates `title`, `location`, `kind`, `target_date`; `DELETE` removes the countdown. Both partners can edit their own couple's events; other couples receive 404. Home recomputes the next meeting.
- Countdown editing is available on Home, in Countdown, and through Our space → Next meeting. The UI asks for confirmation before deletion.
