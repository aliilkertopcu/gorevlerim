# Görevlerim — Todo App

Flutter 3.47+ (web + Android) todo uygulaması. Supabase backend, Riverpod state, GoRouter.
Canlı: https://aitopcu.com/tasks/ (Linode VPS, nginx). Supabase trafiği `https://api.aitopcu.com` proxy'si üzerinden geçer.

## Komutlar
```bash
flutter analyze                      # temiz olmalı (0 issue)
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
- `lib/widgets/task_card.dart` — görev kartı; `part` dosyaları: `task_card_subtasks.dart` (alt görev listesi + ekleme satırı), `task_card_chrome.dart` (basma/hover kabuğu, sürükleme önizlemesi), `task_card_typing.dart`
- `lib/widgets/task_drag.dart` — sürükle-bırak altyapısı: `adaptiveDraggable` (masaüstü anında / dokunmatik 180 ms), `TaskDropTarget` (üst=öne, alt=arkaya, orta=alt görev yap), otomatik kaydırma. Görev listesi düz `Column`, ReorderableListView kullanılmıyor.
- Supabase filtreli stream DELETE olaylarını iletmez → silme/indirme/yükseltme sonrası `ref.invalidate(tasksStreamProvider)`
- `lib/widgets/group_manager.dart` — liste/grup yönetimi; `_GroupDetailViewState` metodları `part` + extension olarak bölündü: `group_detail_members/settings/activity/actions.dart` (extension içinde `setState` yerine `_refresh` kullan)
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
- `supabase/functions/voice-to-tasks` — uygulama içi sesle görev ekleme. JWT auth, günlük 600 s kota (`voice_usage` tablosu, migration 011), Groq `whisper-large-v3` (tr, grup üyesi adları Whisper prompt'unda) → Groq `qwen/qwen3.8-27b` strict JSON schema → `{tasks, actions, ignored}`; `context_tasks` form alanıyla günün görev listesi (id'li) gönderilir, `actions` (complete/uncomplete/postpone/delete/complete_subtask) sadece o id'lerle doğrulanır ve istemci onayda uygular. Form alanı `transcript` verilirse STT atlanır (prompt testi için). Ses klipleri geçici olarak Storage `voice-audio/{user}/{transcript_id}` altında saklanır (`VOICE_KEEP_AUDIO=false` ile kapanır; pg_cron `purge_old_voice_audio` 30 günden eski klipleri siler; iyileştirme bitince bucket + `audio_path` kaldırılacak). DB'ye yazmaz; Flutter önizleme sonrası `task_service.createTask` ile yazar. Secret: `GROQ_API_KEY` (`npx supabase secrets set`).
- Flutter: `lib/widgets/voice_task_dialog.dart` (akış), `lib/services/voice_service.dart` (istemci), `lib/providers/voice_provider.dart`. Kayıt: `record.startStream` PCM16 → 30 s WAV parçaları `?partial=1` ile canlı çevrilir (kota parça başına düşer), durdurunca `transcript` override + tam WAV (`stt_mode=stream`) ile tek LLM çağrısı. PCM örnekleme hızı ölçülür (tarayıcı 16 kHz'i yok sayabilir). Stream desteklenmezse eski dosya yolu (webm/m4a) devreye girer.
- nginx `api.aitopcu.com`: `client_max_body_size 30m` (ses yüklemeleri için; varsayılan 1 MB'da POST CORS'suz 413 → tarayıcıda "Failed to fetch").
- Eval hesabı: `voice-eval@example.com` (parola scratch notlarında; veri yok, silinebilir).
- `supabase/functions/todo-api` — API key ile REST (`x-api-key` / Bearer / `?api_key=`): tasks list/create/patch/delete/complete/postpone, `PATCH /subtasks/:id`, groups. Her yazma isteği grup üyeliğiyle yetkilendirilir (`assertTaskAccess`/`assertGroupAccess`). `api_keys` tablosu, `lib/services/api_key_service.dart`, `lib/widgets/ai_setup_dialog.dart` (menüde gizli).
- `mcp_server/` — Node MCP server (stdio), `todo-api` üzerinden çalışan ince istemci; kullanıcı kendi `TODO_API_KEY`'i ile bağlar (service key gerekmez). Kurulum: `mcp_server/README.md`.
- Kota: `profiles.voice_limit_sec` (migration 014) kullanıcı bazlı override; NULL ise `VOICE_DAILY_LIMIT_SEC` (600).
- Geçmiş: `voice_transcripts` (migration 013), fonksiyonda `?history=1`.
- ChatGPT Custom GPT entegrasyonu 2026-08-29'da tamamen kaldırıldı (gpt-auth/gpt-oauth fonksiyonları, gpt_connect_screen, onboarding kartı).

## Sunucu
- Linode 172.105.93.29, SSH key `~/.ssh/linode_admin`
- nginx: `/tasks/` → `/var/www/gorevlerim/`, `/` → Ghost blog (8080), `api.aitopcu.com` → Supabase proxy (resolver ile lazy DNS)
- ⚠️ nginx `/tasks/` bloğu `Cache-Control: no-cache` gönderir (2026-08-31'de eklendi, yedek `/root/aitopcu.com.bak.*`). Öncesinde hiç cache header'ı yoktu; tarayıcı sezgisel önbelleklemeyle eski build'i servis ediyor, yeni sürüm sadece Ctrl+F5 ile geliyordu. Flutter dosya adlarında içerik hash'i taşımadığı için (main.dart.js, flutter_bootstrap.js hep aynı isim) revalidation şart — ETag ile 304 dönüyor, maliyeti yok
- Flutter'ın service worker'ı artık kendini kaldıran sürüm; `flutter_bootstrap.js` yalnızca zaten bir kayıt varsa register ediyor, dolayısıyla eski SW'ler ilk ziyarette temizleniyor (PWA olarak kurulu istemciler dahil)
- Supabase free tier — inaktivitede pause olur; nginx'in bu durumda ayakta kalması için proxy_pass değişkenli

## Konvansiyonlar
- UI metinleri ve changelog Türkçe, commit mesajları İngilizce
- Yeni ekran/dialog eklerken `DesktopDialog` sistemini kullan, Material `showDialog` değil
- Tasarım token'ları: renkler `Theme.of(context).colorScheme` rollerinden (tema, grup renginden `ColorScheme.fromSeed` ile türetilir — `main.dart`); köşeler `Corners.small/medium/large` (butonlar Stadium); boşluklar `Gap` (4/8 ritmi); yazılar `textTheme` (Plus Jakarta Sans); hareket `Anim` (giriş 400/`enterCurve`, çıkış 200/`exitCurve`, `Anim.enabled(context)` reduced-motion). Ham hex/`Colors.grey` YAZMA. Durum renkleri `AppTheme.statusColor/statusBackground(context,...)`. Kurallar: `ui-ux-pro-max` ve `material-3` skill'leri
- Animasyon süreleri `lib/theme/animation_constants.dart` (`Anim`) içinden
- ⚠️ İşletim sisteminde "hareket azaltma" açıkken Flutter `AnimationController` sürelerini **20 kat** kısaltır (`AnimationBehavior.normal`). Kasıtlı, kullanıcının istediği animasyonlarda `animationBehavior: AnimationBehavior.preserve` kullan (örn. `confetti_burst.dart`)
- Kutlama animasyonu: `assets/animations/confetti.json` (LottieFiles, Lottie Simple License — `assets/animations/CREDITS.md`)
- Kutlama sesi: `assets/sounds/cheer.mp3` (4,4 sn tezahürat; kullanıcının verdiği dosyadan kırpıldı — `assets/sounds/CREDITS.md`). Çalma noktası `celebrate(context)` (`confetti_burst.dart`), platforma göre `lib/utils/cheer.dart`
- ⚠️ Web'de ses için `audioplayers` KULLANMA: ilk `create()` çağrısı 30 sn timeout ile takılıyor. Ayrıca `<audio>` elementi de bazı Chrome bağlamlarında `readyState 0`'da kalıyor. Web tarafı Web Audio API ile çalışıyor (`cheer_web.dart`: fetch → `decodeAudioData` → `BufferSource`); `audioplayers` sadece mobil/masaüstünde (`cheer_io.dart`)
- Testler: `flutter test` (animation, task_drag bölge hesabı, tasksProvider refresh/optimistic). Ses prompt regresyonu: `VOICE_EVAL_JWT=<token> python scripts/voice_eval/run.py` — `cases.json` gerçek kayıtlardan kurulur, prompt değişikliğinden sonra 40/40 beklenir.

## Notlar
- `DEVELOPMENT_LOG.md` kilometre taşları; güncel gerçek kaynak bu dosya + changelog.dart
- `.github/workflows/keepalive.yml` 3 günde bir Supabase REST'e ping atar (free tier pause'u önler); secret: `SUPABASE_ANON_KEY`
- Kullanıcı silme: migration 015/016 ile FK'lar SET NULL, kişisel grup trigger ile silinir (`npx supabase db query --linked "delete from auth.users where email='…'"`)
- `.claude/settings.local.json` ve `supabase/.temp/` gitignore'da (2026-08-29)
- Android release imzası: `android/key.properties` + `android/app/upload-keystore.jks` (her ikisi gitignored, yedekle!). `pubspec.yaml` version alanı 1.0.0+1 (uygulama sürümü `lib/version.dart`'ta)
