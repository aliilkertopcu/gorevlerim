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
