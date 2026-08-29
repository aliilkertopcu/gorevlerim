# Görevlerim MCP Server

Claude Desktop / Claude Code'dan görevlerini sohbetle yönetmeni sağlar. Uygulamadaki
`todo-api` üzerinden çalışır; makinede sadece **kendi API anahtarın** durur.

## Kurulum

1. Uygulamada API anahtarını al (menü → *AI entegrasyonu* → kopyala). Format: `gorevlerim_…`
2. Bu klasörde bağımlılıkları kur:
   ```bash
   cd mcp_server && npm install
   ```
3. Claude Desktop config'ine ekle (`%APPDATA%\Claude\claude_desktop_config.json` — Windows,
   `~/Library/Application Support/Claude/claude_desktop_config.json` — macOS):
   ```json
   {
     "mcpServers": {
       "gorevlerim": {
         "command": "node",
         "args": ["C:/Users/hp/development/personalProjects/todo_app/mcp_server/index.js"],
         "env": { "TODO_API_KEY": "gorevlerim_xxxxxxxxxxxx" }
       }
     }
   }
   ```
   Claude Code için:
   ```bash
   claude mcp add gorevlerim -e TODO_API_KEY=gorevlerim_xxx -- node C:/Users/hp/development/personalProjects/todo_app/mcp_server/index.js
   ```
4. Claude Desktop'ı yeniden başlat. "Bugünkü görevlerim neler?" diye sor.

## Araçlar

| Araç | Ne yapar |
|---|---|
| `list_groups` | Listelerini gösterir (id'leriyle) |
| `list_tasks` | Bir günün görevleri + alt görevleri (id'leriyle) |
| `add_task` | Görev ekle; `subtasks` ile alt görevler, `titles` ile çoklu görev |
| `update_task` | Başlık / açıklama / durum / tarih / bloke sebebi |
| `complete_task` | Sıra numarası veya id ile tamamla |
| `complete_subtask` | Alt görevi tamamla / geri al |
| `postpone_task` | Başka güne ertele |
| `delete_task` | Kalıcı sil |

Tarihler: `YYYY-MM-DD`, `bugün/today`, `yarın/tomorrow`, `dün/yesterday`.
Tüm istekler grup üyeliğiyle yetkilendirilir — sadece üyesi olduğun listelerdeki görevlere erişirsin.
