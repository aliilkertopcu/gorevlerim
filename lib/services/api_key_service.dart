import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiKeyService {
  final SupabaseClient _client;

  ApiKeyService(this._client);

  /// Get existing API key or create a new one
  Future<String> getOrCreateApiKey(String userId) async {
    // Check for existing key
    final existing = await _client
        .from('api_keys')
        .select('key')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      return existing['key'] as String;
    }

    // Create new key
    final newKey = _generateKey();
    await _client.from('api_keys').insert({
      'user_id': userId,
      'key': newKey,
    });

    return newKey;
  }

  /// Delete and regenerate API key
  Future<String> regenerateApiKey(String userId) async {
    // Delete existing
    await _client.from('api_keys').delete().eq('user_id', userId);

    // Create new
    final newKey = _generateKey();
    await _client.from('api_keys').insert({
      'user_id': userId,
      'key': newKey,
    });

    return newKey;
  }

  /// Get last used timestamp
  Future<DateTime?> getLastUsed(String userId) async {
    final data = await _client
        .from('api_keys')
        .select('last_used_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (data != null && data['last_used_at'] != null) {
      return DateTime.parse(data['last_used_at']);
    }
    return null;
  }

  /// Generate a random API key
  String _generateKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final randomPart = List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
    return 'gorevlerim_$randomPart';
  }

  /// Generate the AI prompt with user's API key
  String generateAIPrompt(String apiKey) {
    return '''# Görevlerim AI Asistanı

Görev eklemek istediğimde aşağıdaki API'yi kullan:

## Endpoint
POST https://njzmorqwcsdnjjtvvmgd.supabase.co/functions/v1/todo-api/tasks

## Headers
Content-Type: application/json
x-api-key: $apiKey

## Görev Ekleme Formatları

### Tek görev:
{"title": "Market alışverişi", "date": "today"}

### Birden fazla görev:
{"titles": ["market", "temizlik", "fatura"], "date": "today"}

### Alt görevli (subtask):
{
  "title": "Market alışverişi",
  "subtasks": ["süt", "ekmek", "yumurta"],
  "date": "today"
}

## Tarih Seçenekleri
- "today" veya "bugün" → bugün
- "tomorrow" veya "yarın" → yarın
- "2025-02-05" → belirli tarih

## Örnek Kullanım

"Bugün market, temizlik yapılacak, fatura ödenecek" dersem:
POST body: {"titles": ["market", "temizlik", "fatura öde"], "date": "today"}

"Yarın için doktor randevusu al, ilaçları al" dersem:
POST body: {"titles": ["doktor randevusu al", "ilaçları al"], "date": "tomorrow"}

"Market alışverişi yap, alınacaklar: süt, ekmek, yumurta, peynir" dersem:
POST body: {"title": "Market alışverişi", "subtasks": ["süt", "ekmek", "yumurta", "peynir"], "date": "today"}

## Önemli Notlar
- Ses kaydımda alakasız şeyler olabilir (köpeğe komut verme, araba sesi vb). Sadece görevleri çıkar.
- Her zaman JSON formatında POST isteği at.
- Başarılı olursa API "X görev eklendi" mesajı döner.''';
  }
}
