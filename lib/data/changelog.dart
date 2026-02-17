class ChangelogEntry {
  final String version;
  final String date;
  final List<String> features;
  final List<String> fixes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    this.features = const [],
    this.fixes = const [],
  });
}

const List<ChangelogEntry> changelog = [
  // En yeni üstte
  ChangelogEntry(
    version: '0.19.1',
    date: '2026-02-17',
    fixes: [
      'Bloke edilen alt görevler için "Blokeyi Kaldır" seçeneği eklendi',
      'Bloke alt görev görselliği iyileştirildi — kenarlık, ikon ve arka plan renklendirmesi',
      'Alt görev bloke ederken Ctrl+Enter ile kayıt desteği',
      'Alt görev düzenleme popup\'ında Ctrl+Enter ile kayıt desteği',
    ],
  ),
  ChangelogEntry(
    version: '0.19.0',
    date: '2026-02-17',
    features: [
      'Kişisel grup artık düzenlenebilir — isim, renk, açıklama, ayarlar',
      'Yeni kullanıcılar için otomatik kişisel grup oluşturma',
      'Yapılmamış görevleri bugüne taşı ayarı — geçmiş günlerdeki tamamlanmamış görevler bugünde görünür',
      'Onboarding sayfasına topluluk linkleri — ChatGPT, WhatsApp, beta test grubu',
    ],
  ),
  ChangelogEntry(
    version: '0.18.5',
    date: '2026-02-17',
    fixes: [
      'Davet kabul sonrası ana ekran katılınan grubu gösteriyor (kişisel görevler yerine)',
    ],
  ),
  ChangelogEntry(
    version: '0.18.4',
    date: '2026-02-17',
    features: [
      'Basılı tutma eşiği 300ms — scroll ve swipe sırasında animasyon tetiklenmiyor',
    ],
  ),
  ChangelogEntry(
    version: '0.18.3',
    date: '2026-02-17',
    features: [
      '3 aşamalı basılı tutma animasyonu — 100ms eşik, kademeli büyüme (1.04x), sürükleme modunda %70 saydamlık',
    ],
  ),
  ChangelogEntry(
    version: '0.18.2',
    date: '2026-02-17',
    features: [
      'Basılı tutma animasyonu — sürükleme başlamadan önce gölge ve hafif büyüme efekti',
      'Swipe animasyonu — gün değiştirirken kayma ve yön okları',
      'Hover efekti — masaüstünde görev kartına fareyle gelince hafif vurgu',
      'Görev kartının tamamından sürükleme — sadece başlıktan değil her yerinden',
    ],
    fixes: [
      'Cursor simge değişiklikleri kaldırıldı, daha doğal etkileşim',
    ],
  ),
  ChangelogEntry(
    version: '0.18.1',
    date: '2026-02-17',
    features: [
      'Düzenleme izni olmayan üyeler artık görev statüsünü, alt görev sıralamasını değiştiremez',
      'İzinsiz üyelere hamburger menü gizleniyor (ana görev + alt görevler)',
      'Popup pencereler resize edildiğinde tüm ekranı kaplayabiliyor',
      'Sayfa yenilendiğinde son görüntülenen grup ve açık/kapalı görev durumu korunuyor',
    ],
    fixes: [
      'Hikaye metni güncellendi',
    ],
  ),
  ChangelogEntry(
    version: '0.18.0',
    date: '2026-02-17',
    features: [
      'Görev düzenleme izin sistemi — Herkes / Sadece sahibi / Görev bazlı kilit',
      'Grup kurucusu tüm izin kısıtlamalarını bypass eder',
      'Gelişmiş aktivite günlüğü — tüm görev, alt görev ve üye hareketleri loglanıyor',
      'Aktivite günlüğünde sonsuz scroll (infinite scroll)',
      'Bağlantıyla gruba davet sistemi — süre sınırlı davet linkleri',
      'Davet önizleme sayfası — grup bilgisi ve katılma butonu',
      'Davet bağlantısı yönetimi — oluşturma, silme, kopyalama',
      'Menüde "Gruplar" olarak yeniden adlandırıldı',
    ],
    fixes: [
      'Onboarding geri butonu direkt linkle açıldığında login sayfasına yönlendiriyor',
    ],
  ),
  ChangelogEntry(
    version: '0.17.0',
    date: '2026-02-17',
    features: [
      'Onboarding & changelog sayfası',
      'YouTube tanıtım videosu embed (web: iframe, mobil: thumbnail)',
      'Versiyon numaralama sistemi',
      'Menüye "Neler Yeni?" butonu eklendi',
      'Footer\'a versiyon numarası ve onboarding linki eklendi',
    ],
  ),
  ChangelogEntry(
    version: '0.16.0',
    date: '2026-02-17',
    features: [
      'Alt görev düzenleme popupında çok satırlı giriş desteği',
    ],
    fixes: [
      'Android klavye açılınca popup taşma sorunu giderildi',
      'Desktop popup boyutlandırma sonrası metin kutusu genişleme düzeltildi',
    ],
  ),
  ChangelogEntry(
    version: '0.15.0',
    date: '2026-02-17',
    features: [
      'Grup rengi tüm arayüze yansıyor — butonlar, tarih, ikonlar, expand/collapse',
    ],
  ),
  ChangelogEntry(
    version: '0.14.0',
    date: '2026-02-17',
    features: [
      'Giriş ekranı modernizasyonu — logo, gradient, animasyonlar, tab geçişi',
      'Şifre görünürlük butonu',
      'Yeni görevler listenin en üstüne ekleniyor',
    ],
    fixes: [
      'Alt görev sıralama — düzenleme sonrası yeni eklenen alt görevler doğru sıraya yerleşiyor',
    ],
  ),
  ChangelogEntry(
    version: '0.13.0',
    date: '2026-02-17',
    features: [
      'Desktop: sürüklenebilir ve boyutlandırılabilir popup\'lar',
      'Desktop: mouse cursor değişimleri (grab, click)',
      'Mobil: 300ms kısa basılı tutma ile sürükleme',
      'Görev açma/kapama (expand/collapse) — tümünü aç/kapat butonu',
      'Uygulama ismi "Görevlerim" olarak güncellendi',
      'Yeni uygulama ikonu ve favicon tasarımı',
    ],
    fixes: [
      'Görev numarası badge\'leri kaldırıldı, daha temiz görünüm',
    ],
  ),
  ChangelogEntry(
    version: '0.12.0',
    date: '2026-02-17',
    features: [
      'Grup yönetimi: detay görünümü, renk seçici, üye listesi',
      'Grup aktivite günlüğü',
      'Grup açıklama alanı',
      'Dinamik AppBar rengi — seçili grubun rengini yansıtıyor',
    ],
    fixes: [
      'Stream hatalarında yerel veri öncelikli gösterim',
    ],
  ),
  ChangelogEntry(
    version: '0.11.0',
    date: '2026-02-16',
    features: [
      'API anahtarı kopyalama butonu',
      'API anahtarı yenileme: 5 saniye basılı tutarak tetikleme',
    ],
  ),
  ChangelogEntry(
    version: '0.10.0',
    date: '2026-02-16',
    features: [
      'Gizlilik politikası sayfası — Custom GPT entegrasyonu için',
    ],
  ),
  ChangelogEntry(
    version: '0.9.0',
    date: '2026-02-06',
    features: [
      'AI entegrasyonu — Custom GPT ile görev yönetimi',
      'AI kurulum diyaloğu — API anahtarı oluşturma ve yönetim',
      'Supabase Edge Function ile görev API\'si',
    ],
  ),
  ChangelogEntry(
    version: '0.8.0',
    date: '2026-02-03',
    features: [
      'Google ile giriş',
    ],
    fixes: [
      'Scrollbar düzeltmeleri',
      'Ana ekran yapısı iyileştirildi',
    ],
  ),
  ChangelogEntry(
    version: '0.7.0',
    date: '2026-02-03',
    features: [
      'Koyu/açık tema desteği',
      'Swipe ile gün değiştirme',
      'Hamburger menü ve AppBar iyileştirmeleri',
      'Footer eklendi',
    ],
  ),
  ChangelogEntry(
    version: '0.6.0',
    date: '2026-02-03',
    features: [
      'Alt görev (subtask) desteği — * ile ekle/düzenle',
      'Sürükle-bırak ile görev ve alt görev sıralama',
      'Görev durumları: bekliyor, tamamlandı, bloke, ertelendi',
      'Görev kartı tasarımı yenilendi',
      'Grup seçici widget',
    ],
  ),
  ChangelogEntry(
    version: '0.5.0',
    date: '2026-02-03',
    features: [
      'GitHub Pages ile web dağıtımı (CI/CD)',
    ],
  ),
  ChangelogEntry(
    version: '0.1.0',
    date: '2026-02-02',
    features: [
      'Görev oluşturma, düzenleme, silme',
      'Tarih bazlı görev takibi',
      'Grup sistemi — grup oluşturma ve seçme',
      'Supabase entegrasyonu — gerçek zamanlı veri senkronizasyonu',
      'E-posta/şifre ile giriş ve kayıt',
      'PWA desteği — Chrome\'dan telefona kurulabilir',
      'Responsive tasarım — mobil ve desktop uyumlu',
    ],
  ),
];
