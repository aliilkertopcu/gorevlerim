# Görevlerim - Todo App Geliştirme Günlüğü

**Proje Dizini:** `C:\Users\hp\development\personalProjects\todo_app`
**Tarih:** 2026-02-08

---

## 2026-04-16 — v0.29.1

### Sunucu Kurtarma & UX İyileştirmeleri

**Sorun:** `aitopcu.com` ve `aitopcu.com/tasks` ERR_CONNECTION_REFUSED hatası veriyordu.

**Kök Neden:** Nginx, boot sırasında `proxy_pass` içindeki `njzmorqwcsdnjjtvvmgd.supabase.co` adresini DNS'ten çözümlemeye çalışıyor ancak başarısız oluyordu (Supabase free tier projesi inaktivite nedeniyle pause'a alınmıştı). Bu nedenle nginx başlamıyordu.

**Çözüm:** `/etc/nginx/sites-enabled/api.aitopcu.com` içinde `proxy_pass` sabit hostname yerine değişken kullanacak şekilde güncellendi (`resolver 8.8.8.8; set $supabase https://...`). Bu sayede DNS çözümlemesi startup yerine request anında yapılıyor.

**Ek Geliştirmeler:**
- Linode sunucusuna `linode_admin` SSH key'i eklendi (`C:\Users\hp\.ssh\linode_admin`)
- Bağlantı hatası banner'ı eklendi: sunucu erişilemez olduğunda `ConnectionBanner` widget'ı turuncu banner gösteriyor (home + login ekranlarında)
- Sağ tık context menu: task ve subtask kartlarında sağ tıkla hamburger menüsü mouse konumunda açılıyor; browser'ın native context menu'su `suppressContextMenu()` ile engellendi

### ChatGPT → Whisper AI Planı

**Mevcut durum:** ChatGPT entegrasyonu (GPT Connect ekranı, Edge Function'lar) artık çalışmıyor.

**Planlanan değişiklik:** ChatGPT bağımlılığı tamamen kaldırılacak. Uygulama kendi içinde Whisper AI tabanlı STT (Speech-to-Text) çalıştıracak — harici API key veya OAuth akışı gerekmeyecek.

---

## Proje Özeti

Flutter (Dart) + Supabase Cloud ile todo uygulaması.
- **Frontend**: Flutter Web + Material 3
- **Backend**: Supabase Cloud (Auth + PostgreSQL + Realtime + Edge Functions)
- **AI Entegrasyonu**: Kişisel API key sistemi ile Claude/ChatGPT desteği
- **Deploy**: GitHub Pages (`https://aliilkertopcu.github.io/gorevlerim/`)

---

## ✅ TAMAMLANAN GÖREVLER

### 1. Dark Mode Desteği
- **Dosyalar:**
  - `lib/providers/theme_provider.dart` - Tema state yönetimi (StateNotifier)
  - `lib/theme/app_theme.dart` - Light/Dark tema tanımları
  - `lib/main.dart` - ThemeMode provider dinleme
- **Özellikler:**
  - Light / Dark / Otomatik (sistem) tema seçenekleri
  - SharedPreferences ile kalıcı kayıt
  - Hamburger menüden tema değiştirme

### 2. AppBar Yeniden Tasarımı
- **Dosya:** `lib/screens/home_screen.dart`
- **Özellikler:**
  - Custom Container tabanlı AppBar (Scaffold AppBar yerine)
  - Rounded corners (12px radius)
  - Body ile aynı genişlik (maxWidth: 600px)
  - AppTheme.primaryColor ile sabit renk (#667eea)

### 3. DateNav Dark Mode Uyumluluğu
- **Dosya:** `lib/widgets/date_nav.dart`
- **Özellikler:**
  - `Theme.of(context).brightness` ile dark mode algılama
  - Dark modda uygun arka plan renkleri

### 4. Footer Ekleme
- **Dosya:** `lib/screens/home_screen.dart`
- **Özellikler:**
  - "made with curiosity 🧠" ve "@izmir 2026"
  - SliverFillRemaining ile ekranın en altına sabitlendi
  - Scroll içinde değil, her zaman görünür

### 5. Native Browser Scroll
- **Dosyalar:**
  - `lib/main.dart` - WebScrollBehavior sınıfı
  - `lib/screens/home_screen.dart` - CustomScrollView yapısı
- **Özellikler:**
  - Flutter'ın iç scroll'u yerine tarayıcının native scroll'u
  - Mouse, touch ve trackpad desteği
  - ReorderableListView shrinkWrap ile entegre

### 6. Google OAuth Redirect URL Düzeltmesi
- **Dosya:** `lib/services/auth_service.dart`
- **Değişiklik:**
  ```dart
  // Önceki:
  final redirectUrl = Uri.base.origin;

  // Sonraki:
  final currentPath = Uri.base.path;
  final basePath = currentPath.endsWith('/') ? currentPath : '$currentPath/';
  final redirectUrl = '${Uri.base.origin}$basePath';
  ```
- **Sonuç:** `/gorevlerim` subpath'i artık korunuyor

### 7. AI Entegrasyonu (Kişisel API Key Sistemi)
- **Veritabanı:**
  - `supabase/migrations/002_api_keys.sql` - api_keys tablosu
  - RLS politikaları ile güvenlik
- **Edge Function:**
  - `supabase/functions/todo-api/index.ts` - API key doğrulama
  - Database lookup ile kullanıcı kimliği
  - `last_used_at` takibi
- **Flutter:**
  - `lib/services/api_key_service.dart` - Key oluşturma/yönetim
  - `lib/widgets/ai_setup_dialog.dart` - Kullanıcı arayüzü
  - Kopyalanabilir API key ve prompt

### 8. Türkçe Karakter Encoding Düzeltmesi
- **Dosya:** `supabase/functions/todo-api/index.ts`
- **Değişiklik:** Tüm response'larda `charset=utf-8` eklendi
  ```typescript
  "Content-Type": "application/json; charset=utf-8"
  ```
- **Test:** PowerShell'de UTF-8 byte array gönderme gerekiyor:
  ```powershell
  $body = '{"title": "Türkçe görev", "date": "today"}'
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  Invoke-RestMethod -Uri "..." -Method POST -Headers @{...} -Body $bytes
  ```

### 9. Edit Modal Klavye Kısayolları
- **Dosya:** `lib/widgets/task_card.dart`
- **Özellikler:**
  - CTRL+ENTER ile kaydetme (hem başlık hem açıklama alanında)
  - TAB ile açıklama alanına geçiş (`textInputAction: TextInputAction.next`)
  - KeyboardListener wrapper ile keyboard event handling

### 10. Pull-to-Refresh
- **Dosya:** `lib/screens/home_screen.dart`
- **Özellikler:**
  - RefreshIndicator ile sarmalama
  - CustomScrollView + AlwaysScrollableScrollPhysics
  - Boş liste ve dolu liste için çalışıyor

### 11. Swipe ile Gün Değiştirme
- **Dosya:** `lib/screens/home_screen.dart`
- **Özellikler:**
  - GestureDetector.onHorizontalDragEnd
  - Sağa swipe → önceki gün
  - Sola swipe → sonraki gün
  - Velocity threshold: 300

---

## 🔄 YAPILACAKLAR / BEKLEYEN GÖREVLER

### 1. Header ve Footer Sabitleme (Düzenleme Gerekli)
**Mevcut Durum:** Footer SliverFillRemaining ile scroll sonunda.
**İstenen:** Az görev olduğunda da header en üstte, footer en altta sabit kalsın.

**Çözüm Önerisi:**
```dart
Scaffold(
  body: Column(
    children: [
      // HEADER - Sabit üstte
      Container(color: AppTheme.primaryColor, ...),

      // CONTENT - Expanded ile kalan alan
      Expanded(
        child: RefreshIndicator(
          child: ListView/CustomScrollView(...),
        ),
      ),

      // FOOTER - Sabit altta
      Container(child: _buildFooter()),
    ],
  ),
)
```

### 2. Claude/ChatGPT Test
- AI Entegrasyonu menüsünden prompt kopyala
- Claude veya ChatGPT'ye yapıştır
- "Bugün market alışverişi yap" gibi komut ver
- Görevin eklendiğini doğrula

### 3. Supabase Edge Function Deploy
Edge Function'ı güncelledikten sonra Supabase Dashboard'dan manuel deploy gerekiyor:
1. Supabase Dashboard → Functions → todo-api
2. Kodu `supabase/functions/todo-api/index.ts` dosyasından kopyala
3. Deploy et

---

## 📁 PROJE YAPISI

```
todo_app/
├── lib/
│   ├── main.dart                     # App başlatma, tema, scroll behavior
│   ├── router.dart                   # GoRouter
│   ├── models/
│   │   ├── task.dart                 # Task & Subtask modelleri
│   │   ├── group.dart                # Group modeli
│   │   └── app_user.dart             # Kullanıcı modeli
│   ├── services/
│   │   ├── auth_service.dart         # Supabase Auth + OAuth
│   │   ├── task_service.dart         # Task CRUD + realtime
│   │   ├── group_service.dart        # Grup yönetimi
│   │   └── api_key_service.dart      # AI API key yönetimi
│   ├── providers/
│   │   ├── auth_provider.dart        # Auth state
│   │   ├── task_provider.dart        # Task state + optimistic updates
│   │   ├── group_provider.dart       # Grup state
│   │   └── theme_provider.dart       # Tema state (Light/Dark/System)
│   ├── screens/
│   │   ├── home_screen.dart          # Ana ekran
│   │   └── login_screen.dart         # Giriş ekranı
│   ├── widgets/
│   │   ├── date_nav.dart             # Tarih navigasyonu
│   │   ├── task_card.dart            # Görev kartı
│   │   ├── subtask_item.dart         # Alt görev
│   │   ├── task_form.dart            # Yeni görev formu
│   │   ├── group_selector.dart       # Grup seçici
│   │   ├── group_manager.dart        # Grup yönetimi dialog
│   │   └── ai_setup_dialog.dart      # AI kurulum dialog
│   └── theme/
│       └── app_theme.dart            # Tema tanımları
├── supabase/
│   ├── migrations/
│   │   ├── 001_initial.sql           # Ana tablolar
│   │   └── 002_api_keys.sql          # API keys tablosu
│   └── functions/
│       └── todo-api/
│           └── index.ts              # Edge Function
└── build/web/                        # Build output
```

---

## 🔧 KULLANILAN KOMUTLAR

### Flutter Build
```powershell
cd C:\Users\hp\development\personalProjects\todo_app
flutter build web --release
```

### Local Test
```powershell
flutter run -d chrome
```

### API Test (PowerShell)
```powershell
# UTF-8 destekli görev ekleme
$body = '{"title": "Test görevi", "date": "today"}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
Invoke-RestMethod -Uri "https://njzmorqwcsdnjjtvvmgd.supabase.co/functions/v1/todo-api/tasks" -Method POST -Headers @{"Content-Type"="application/json; charset=utf-8"; "x-api-key"="YOUR_API_KEY"} -Body $bytes
```

---

## 📝 NOTLAR

1. **Doğru Proje Dizini:** `C:\Users\hp\development\personalProjects\todo_app`
   - ~~`C:\Users\hp\Documents\şahsi\todo\todo_app`~~ (KULLANILMIYOR - özel karakter sorunu)

2. **Supabase Bilgileri:**
   - Project URL: `https://njzmorqwcsdnjjtvvmgd.supabase.co`
   - Edge Function: `todo-api`

3. **GitHub Pages:**
   - URL: `https://aliilkertopcu.github.io/gorevlerim/`
   - Base path routing için `Uri.base.path` kullanılıyor

4. **API Key Formatı:** `gorevlerim_xxxxxxxxxxxx` (24 karakter random)

---

## 🐛 BİLİNEN SORUNLAR

1. **PowerShell curl alias:** Windows PowerShell'de `curl` komutu `Invoke-WebRequest`'e alias. `Invoke-RestMethod` veya `irm` kullanılmalı.

2. **Türkçe karakterler (PowerShell):** Body UTF-8 byte array olarak gönderilmeli, aksi halde bozuk kaydediliyor.

3. **Flutter fvm:** Eğer fvm kullanılıyorsa `fvm flutter` prefix'i gerekebilir.
