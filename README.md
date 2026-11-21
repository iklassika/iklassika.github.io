# Репозиторий iKlassika в Cydia

Этот репозиторий — APT-источник для Cydia/Sileo.

## Обновление метаданных

После изменения `.deb` в папке `debs/` запустите:

```bash
bash scripts/generate-repo.sh
```

Скрипт пересоберёт `Packages` (с `Size`, `MD5sum`, `SHA1`, `SHA256` для каждого пакета),
сжатые индексы `Packages.gz`, `Packages.bz2`, `Packages.xz` и добавит в `Release`
контрольные суммы всех индексов.
