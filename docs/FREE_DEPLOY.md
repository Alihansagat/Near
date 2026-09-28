# Бесплатный доступ с двух телефонов

Для iPhone и Android удобнее всего использовать веб-версию как PWA: открыть ссылку в браузере и добавить её на главный экран. Данные синхронизируются через общий API.

1. Создайте бесплатный PostgreSQL-проект в Neon и скопируйте `DATABASE_URL`.
2. Создайте бесплатный web service на Render из этого репозитория. Blueprint `render.yaml` уже задаёт сборку, миграции и проверку `/health/`.
3. В переменных Render укажите `ALLOWED_HOSTS` (домен Render) и временно `CORS_ALLOWED_ORIGINS` (домен будущей веб-версии).
4. В GitHub Pages включите Pages из Actions и добавьте repository variable `API_BASE_URL` со значением `https://ВАШ-RENDER-ДОМЕН/api/`. Workflow `.github/workflows/flutter-web.yml` соберёт Flutter web для адреса `https://alihansagat.github.io/Near/`.
5. После публикации Pages добавьте её адрес в `CORS_ALLOWED_ORIGINS` на Render и перезапустите сервис.
6. Откройте ссылку Pages на обоих телефонах, зарегистрируйте два аккаунта и соедините их кодом приглашения.

Для фото, видео и аудио задайте S3-совместимое хранилище (например, Cloudflare R2) через `S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` и `AWS_S3_ENDPOINT_URL`. Это нужно, потому что локальный диск бесплатного Render временный.

Вариант только для Android — собрать APK и передать файл напрямую. Для двух разных iPhone постоянная бесплатная установка через App Store невозможна без Apple Developer Program, поэтому PWA подходит лучше.
