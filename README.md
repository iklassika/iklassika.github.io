# Репозиторий iKlassika в Cydia

Этот репозиторий — APT-источник для Cydia/Sileo.

## Автоматическое обновление

При каждом push в ветку `main` workflow
[`.github/workflows/update-repo.yml`](.github/workflows/update-repo.yml)
запускает [`scripts/generate-repo.sh`](scripts/generate-repo.sh), который:

1. читает все `.deb` из `debs/` и пересобирает `Packages` (включая `Size`, `MD5sum`, `SHA1`, `SHA256` для каждого `.deb`);
2. пересоздаёт `Packages.gz`, `Packages.bz2`, `Packages.xz`;
3. обновляет `Release`: добавляет `Date` и контрольные суммы всех индексов (`MD5Sum`, `SHA1`, `SHA256`);
4. коммитит и запушивает изменения обратно в репозиторий.

Workflow можно также запустить вручную через **Actions → Update Cydia repo metadata → Run workflow**.

Локально генерация делается так:

```bash
bash scripts/generate-repo.sh
```
