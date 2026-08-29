# Görevlerim — Todo App

Flutter (web + Android) todo uygulaması. Supabase backend, Riverpod state, GoRouter.
Canlı: https://aitopcu.com/tasks/ (Linode VPS, nginx). Supabase trafiği `https://api.aitopcu.com` proxy'si üzerinden geçer.

## Komutlar
```bash
flutter analyze                      # ~6 info-level uyarı normal (group_manager RadioGroup, anonKey deprecation, null-aware lint)
flutter run -d chrome                # lokal test
flutter build web --release --base-href "/tasks/"
flutter build apk --release          # Android; android/key.properties + app/upload-keystore.jks (gitignored) ile imzalanır
npx supabase functions deploy todo-api --no-verify-jwt   # edge function deploy
```

## Deploy protokolü (`deploy` dendiğinde)
1. `lib/data/changelog.dart` — en üste yeni `ChangelogEntry` ekle (Türkçe)
2. `lib/version.dart` — `appVersion` ve `appBuildDate` güncelle (minor bump)
3. `flutter analyze` temiz olmalı (info uyarıları hariç)
4. Commit (İngilizce mesaj, `Release vX.Y.Z: ...`) + `git push`
5. GitHub Actions `deploy.yml` otomatik build alır ve rsync ile sunucuya atar

## Mimari
- `lib/main.dart` — Supabase init (URL: api.aitopcu.com), tema, WebScrollBehavior
- `lib/router.dart` — GoRouter; `/onboarding`, `/invite` auth redirect dışında
- `lib/providers/` — Riverpod: auth, task (optimistic update + realtime stream), group, chat, connection (15s health check), theme
- `lib/services/` — Supabase erişim katmanı; `history_service.dart` salt okunur (loglama DB trigger'da)
- `lib/widgets/task_card.dart` (1600 satır) — en karmaşık widget: subtask düzenleme, sürükleme, sağ tık menü
- `lib/widgets/task_drag.dart` — sürükle-bırak altyapısı: `adaptiveDraggable` (masaüstü anında / dokunmatik 180 ms), `TaskDropTarget` (üst=öne, alt=arkaya, orta=alt görev yap), otomatik kaydırma. Görev listesi düz `Column`, ReorderableListView kullanılmıyor.
- Supabase filtreli stream DELETE olaylarını iletmez → silme/indirme/yükseltme sonrası `ref.invalidate(tasksStreamProvider)`
- `lib/widgets/group_manager.dart` (1800 satır) — liste/grup yönetimi, izinler, davet linkleri, aktivite günlüğü
- `lib/widgets/desktop_dialog.dart` — kendi dialog sistemi: desktop'ta sürüklenebilir/boyutlanabilir, mobilde klavye uyumlu
- `lib/widgets/focus_mode.dart` — Pomodoro (15/25/45/60 dk + overtime)
- `currentOwnerColorProvider` seçili grubun rengini tüm UI'a yayar
- Web-only kod için conditional import: `web_utils.dart` / `web_utils_stub.dart`, `youtube_embed_web.dart` / `_stub.dart`

## Veri modeli (Supabase)
- Her görev bir gruba aittir (`owner_type='group'`); her kullanıcının `is_personal=true` bir grubu vardır (migration 006)
- `tasks` → `subtasks`; status: pending / completed / blocked / postponed / deleted
- `groups`, `group_members`, `group_invites`, izin modu: herkes / sadece sahibi / görev bazlı kilit
- `task_messages` — görev içi sohbet + typing indicator (realtime)
- `task_history` — DB trigger ile audit trail (migration 009, 010)
- `api_keys` — kullanıcı başına 1 anahtar (`gorevlerim_xxx`), AI entegrasyonu için
- Migration'lar `supabase/migrations/` altında, sırayla uygulanır; şema değişikliğinde yeni numaralı dosya ekle

## AI / ses entegrasyonu
- `supabase/functions/voice-to-tasks` — uygulama içi sesle görev ekleme. JWT auth, günlük 600 s kota (`voice_usage` tablosu, migration 011), Groq `whisper-large-v3-turbo` (tr) → Groq `qwen/qwen3.8-27b` strict JSON schema → `{tasks, ignored}`. DB'ye yazmaz; Flutter önizleme sonrası `task_service.createTask` ile yazar. Secret: `GROQ_API_KEY` (`npx supabase secrets set`).
- Flutter: `lib/widgets/voice_task_dialog.dart` (akış), `lib/services/voice_service.dart` (istemci), `lib/providers/voice_provider.dart`; kayıt `record` paketi (web: webm/opus blob, mobil: dosya).
- `supabase/functions/todo-api` — API key ile REST (`x-api-key` / Bearer / `?api_key=`): tasks list/create/patch/delete/complete/postpone, `PATCH /subtasks/:id`, groups. Her yazma isteği grup üyeliğiyle yetkilendirilir (`assertTaskAccess`/`assertGroupAccess`). `api_keys` tablosu, `lib/services/api_key_service.dart`, `lib/widgets/ai_setup_dialog.dart` (menüde gizli).
- `mcp_server/` — Node MCP server (stdio), `todo-api` üzerinden çalışan ince istemci; kullanıcı kendi `TODO_API_KEY`'i ile bağlar (service key gerekmez). Kurulum: `mcp_server/README.md`.
- Kota: `profiles.voice_limit_sec` (migration 014) kullanıcı bazlı override; NULL ise `VOICE_DAILY_LIMIT_SEC` (600).
- Geçmiş: `voice_transcripts` (migration 013), fonksiyonda `?history=1`.
- ChatGPT Custom GPT entegrasyonu 2026-08-29'da tamamen kaldırıldı (gpt-auth/gpt-oauth fonksiyonları, gpt_connect_screen, onboarding kartı).

## Sunucu
- Linode 172.105.93.29, SSH key `~/.ssh/linode_admin`
- nginx: `/tasks/` → `/var/www/gorevlerim/`, `/` → Ghost blog (8080), `api.aitopcu.com` → Supabase proxy (resolver ile lazy DNS)
- Supabase free tier — inaktivitede pause olur; nginx'in bu durumda ayakta kalması için proxy_pass değişkenli

## Konvansiyonlar
- UI metinleri ve changelog Türkçe, commit mesajları İngilizce
- Yeni ekran/dialog eklerken `DesktopDialog` sistemini kullan, Material `showDialog` değil
- Renk için `AppTheme` + `currentOwnerColorProvider`; sabit renk kullanma
- Animasyon süreleri `lib/theme/animation_constants.dart` (`Anim`) içinden
- Testler `test/` altında az (animation_test, widget_test); davranış değişikliğinde `flutter analyze` yeterli sayılıyor

## Notlar
- `DEVELOPMENT_LOG.md` kilometre taşları; güncel gerçek kaynak bu dosya + changelog.dart
- `.github/workflows/keepalive.yml` 3 günde bir Supabase REST'e ping atar (free tier pause'u önler); secret: `SUPABASE_ANON_KEY`
- Kullanıcı silme: migration 015/016 ile FK'lar SET NULL, kişisel grup trigger ile silinir (`npx supabase db query --linked "delete from auth.users where email='…'"`)
- `.claude/settings.local.json` ve `supabase/.temp/` gitignore'da (2026-08-29)
- Android release imzası: `android/key.properties` + `android/app/upload-keystore.jks` (her ikisi gitignored, yedekle!). `pubspec.yaml` version alanı 1.0.0+1 (uygulama sürümü `lib/version.dart`'ta)
