#!/usr/bin/env python3
"""Поле плюс приём отклика: один процесс, один порт, один читатель.

Обычный статический сервер отдаёт движок и собранный день. Этот добавляет к нему
единственный маршрут `/отклик`, по которому записывается ответ на вопрос ритуала.

Зачем маршрут, а не кнопка бота. Кнопка с `callback_data` требует, чтобы кто-то
читал обновления у бота. Читатель у токена ровно один: второй процесс начинает
растаскивать поток, а вебхук на том же токене отвечает на опрос ошибкой 409.
Кнопка со ссылкой не требует ничего. Бот только отправляет, клик открывает эту
страницу, страница записывает отклик.

Запуск:
    python3 поле.py              порт 8777, слушает только 127.0.0.1
    KREST_PORT=8899 python3 поле.py

Запись идёт в `источники/отклики.json`, его читает адаптер `отклики`.
Наружу сервер не выходит: адрес всегда 127.0.0.1.
"""
import os, json, pathlib, datetime as dt, urllib.parse, http.server, socketserver

КОРЕНЬ = pathlib.Path(__file__).parent
ФАЙЛ = КОРЕНЬ / "источники" / "отклики.json"
ПОРТ = int(os.environ.get("KREST_PORT", "8777"))
ЛУЧИ = {"обязательства", "будущее", "ресурсы", "прошлое"}

СТРАНИЦА = """<!doctype html><meta charset="utf-8">
<title>записано</title>
<style>
 body{{background:#111;color:#eee;font:15px/1.7 ui-monospace,SFMono-Regular,Menlo,monospace;
      display:grid;place-items:center;height:100vh;margin:0}}
 div{{text-align:center}} b{{color:#db303d}} a{{color:#888}}
</style>
<div><p>записано: <b>{луч}</b></p><p>{событие}</p><p><a href="/движок/">открыть крест</a></p></div>
"""


def записать(событие, луч, текст=""):
    """Дописывает отклик в файл. Файл это список, порядок хронологический."""
    ФАЙЛ.parent.mkdir(parents=True, exist_ok=True)
    try:
        было = json.loads(ФАЙЛ.read_text(encoding="utf-8"))
        if not isinstance(было, list):
            было = []
    except (FileNotFoundError, json.JSONDecodeError):
        было = []
    было.append({
        "событие": событие,
        "луч": луч,
        "текст": текст,
        "время": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    })
    ФАЙЛ.write_text(json.dumps(было, ensure_ascii=False, indent=1), encoding="utf-8")
    return len(было)


class Обработчик(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *а, **кв):
        super().__init__(*а, directory=str(КОРЕНЬ), **кв)

    def log_message(self, формат, *а):
        """Тихий журнал: в него не должны попадать тексты откликов."""
        return

    def _путь(self):
        """Строка запроса приходит разобранной как latin-1: http.server читает её так.
        Сырые не-ASCII байты в адресе иначе превращаются в мусор."""
        try:
            return self.path.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            return self.path

    def отказ(self, луч):
        """Отказ по неизвестному лучу.

        Причина статуса HTTP кодируется в latin-1, и кириллица в ней роняет поток
        обработчика целиком: клиент получает обрыв соединения вместо кода. Поэтому
        причина латиницей, а объяснение уходит в тело ответа.
        """
        тело = ("луч должен быть одним из: " + ", ".join(sorted(ЛУЧИ))
                + (f"\nпришло: {луч}" if луч else "\nлуч не передан")).encode("utf-8")
        self.send_response(400, "Bad Request")
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(тело)))
        self.end_headers()
        self.wfile.write(тело)

    def do_GET(self):
        адрес = urllib.parse.urlparse(self._путь())
        if urllib.parse.unquote(адрес.path) != "/отклик":
            return super().do_GET()

        поля = urllib.parse.parse_qs(адрес.query)
        луч = (поля.get("луч") or [""])[0]
        событие = (поля.get("событие") or [""])[0]
        текст = (поля.get("текст") or [""])[0]

        if луч not in ЛУЧИ:
            self.отказ(луч)
            return

        всего = записать(событие, луч, текст)
        тело = СТРАНИЦА.format(луч=луч, событие=событие or f"откликов всего: {всего}")
        байты = тело.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(байты)))
        self.end_headers()
        self.wfile.write(байты)


class Сервер(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with Сервер(("127.0.0.1", ПОРТ), Обработчик) as сервер:
        print(f"поле:    http://127.0.0.1:{ПОРТ}/движок/")
        print(f"отклик:  http://127.0.0.1:{ПОРТ}/отклик?событие=проба&луч=ресурсы")
        print("остановить: Ctrl+C")
        try:
            сервер.serve_forever()
        except KeyboardInterrupt:
            print()
