# Görevlerim — Geliştirme Günlüğü

Güncel mimari ve çalışma kuralları için **CLAUDE.md**, sürüm bazlı değişiklikler için
`lib/data/changelog.dart` esas alınır. Bu dosya yalnızca kilometre taşlarını tutar.

## 2026-08-29 — v0.30 → v0.32
- ChatGPT Custom GPT entegrasyonu tamamen kaldırıldı; yerine uygulama içi **sesle görev ekleme**
  (`voice-to-tasks` edge function: Groq `whisper-large-v3-turbo` + `qwen/qwen3.8-27b`, strict JSON).
  Günlük kota (`voice_usage`), kayıt geçmişi (`voice_transcripts`), kullanıcı bazlı limit (`profiles.voice_limit_sec`).
- Google girişi hatası: Supabase Auth Site URL'de başta boşluk vardı → düzeltildi.
- `todo-api` yetkilendirme (grup üyeliği), `PATCH /subtasks/:id`; `mcp_server/` API-key tabanlı ince istemci.
- Android release imzalama (`android/key.properties`, gitignored).
- Sürükle-bırak yeniden yazıldı (`lib/widgets/task_drag.dart`): tüm kart tutulabilir, masaüstü anında /
  dokunmatik 180 ms, görev ↔ alt görev dönüşümü. Fareyle sayfa kaydırma kapatıldı.
- Yazma sonrası stream yenilemede spinner kaldırıldı (`isRefreshing` ayrımı).

## 2026-04 — v0.29
- Sunucu kurtarma: Supabase pause'u nginx'i düşürüyordu → `proxy_pass` değişkenli (lazy DNS).
- Bağlantı banner'ı, sağ tık menüleri.

## 2026-03 — v0.26–0.28
- Animasyon sistemi, performans, DB trigger'lı görev geçmişi.

## 2026-02 — v0.1–0.25
- Temel uygulama, gruplar/izinler/davetler, odak modu, görev içi sohbet, onboarding.
- GitHub Pages → Linode (`aitopcu.com/tasks`), Supabase `api.aitopcu.com` proxy.
- Custom GPT entegrasyonu (sonradan kaldırıldı).
