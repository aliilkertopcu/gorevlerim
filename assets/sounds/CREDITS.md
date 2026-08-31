# Ses dosyaları

## cheer.mp3 — kutlama tezahüratı

Kullanıcının sağladığı `driken5482-applause-cheer-236786.mp3` dosyasından
hazırlandı (kaynak dosya adı Pixabay indirmelerinin biçimine benziyor;
lisans kaydı için kaynağı teyit et).

Uygulanan işlemler:

```bash
ffmpeg -ss 0.92 -t 4.4 -i driken5482-applause-cheer-236786.mp3 \
  -af "volume=3.7dB,afade=t=out:st=3.5:d=0.9" \
  -c:a libmp3lame -b:a 128k -ar 44100 cheer.mp3
```

- Baştaki ~0,92 sn sessizlik kırpıldı (yoksa ses bir saniye geç geliyordu)
- 4,4 sn'ye kısaltıldı, son 0,9 sn fade out
- +3,7 dB (kaynak tepe değeri -4,3 dBFS idi); sonuç: tepe -0,6 dBFS, rms 0,118
