# Full 記帳 — on-device (`app_local`)

Local-first Flutter client. Ledger data lives in SQLite on the device (Drift).
There is no login. Optional 密碼鎖 stores a salted PBKDF2-HMAC-SHA256 hash
(at least 100,000 iterations) in the device keystore. Face ID is a shortcut
only while that password lock is on, and falls back to the password.

```
flutter analyze
flutter test
flutter build apk --debug
```
