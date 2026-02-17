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
  ChangelogEntry(
    version: '0.1.0',
    date: '2026-02-17',
    features: [
      'Görev oluşturma, düzenleme, silme',
      'Alt görev (subtask) desteği — ana görev açıklamasında * ile ekle/düzenle',
      'Sürükle-bırak ile görev ve alt görev sıralama',
      'Görev durumları: bekliyor, tamamlandı, bloke, ertelendi',
      'Tarih bazlı görev takibi — swipe ile gün değiştir',
      'Grup sistemi — grup oluşturma, renk seçimi, üye yönetimi',
      'Grup rengi tüm arayüze yansıyor (butonlar, tarih, ikonlar)',
      'Google ile giriş',
      'Koyu/açık tema desteği',
      'AI entegrasyonu — Custom GPT ile görev yönetimi',
      'Desktop: sürüklenebilir ve boyutlandırılabilir popup\'lar',
      'Desktop: mouse cursor değişimleri (grab, click)',
      'Mobil: 300ms kısa basılı tutma ile sürükleme',
      'Görev açma/kapama (expand/collapse) — tümünü aç/kapat butonu',
      'PWA desteği — Chrome\'dan telefona kurulabilir',
      'Onboarding & changelog sayfası',
    ],
    fixes: [
      'Alt görev ekleme/silme sonrası arayüz güncellenmeme sorunu',
      'Alt görev sıralama — yeni eklenen alt görevler doğru sıraya yerleşiyor',
      'Android klavye açılınca popup taşma sorunu',
      'Desktop popup resize sonrası metin kutusu genişleme',
      'Yeni görevler listenin en üstüne ekleniyor',
    ],
  ),
];
