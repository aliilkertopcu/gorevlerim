# Görevlerim

Günlük görev takibi — Flutter (web + Android) ve Supabase.
Canlı: **https://aitopcu.com/tasks/**

## Öne çıkanlar
- 🎤 **Sesle görev ekleme** — konuş, yapay zeka görev/alt görevlere ayırsın (Groq Whisper + LLM, önizleme ile onay)
- 👥 Ortak listeler, izinler, davet linkleri, görev içi sohbet, aktivite günlüğü
- ⏱️ Odak modu (Pomodoro), geçmiş günlerden devreden görevler
- 🖱️ Sürükle-bırak: sıralama, görev ↔ alt görev dönüşümü
- 🤖 Claude ile kullanım: `mcp_server/` (kendi API anahtarınla)

## Geliştirme
```bash
flutter pub get
flutter run -d chrome
flutter analyze
flutter build web --release --base-href "/tasks/"
flutter build apk --release        # android/key.properties gerekir
```
Deploy: `main`'e push → GitHub Actions → Linode (rsync).

Backend (Supabase): `supabase/migrations/` sırayla uygulanır (`npx supabase db push`),
edge function'lar `npx supabase functions deploy <name> --no-verify-jwt`.

Ayrıntılı mimari, konvansiyonlar ve deploy protokolü: **[CLAUDE.md](CLAUDE.md)**.
Sürüm geçmişi: `lib/data/changelog.dart` (uygulama içinde "Neler Yeni?").
