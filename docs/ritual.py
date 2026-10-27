#!/usr/bin/env python3
"""Optional personal ritual. Dry-run by default; no updates polling or scheduling."""
import argparse
import json
import os
import urllib.parse
import urllib.request


def payload(base, chat, event):
    url = urllib.parse.urlsplit(base)
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
        raise ValueError('Use your own private HTTPS board root without credentials or query')
    def button(label, arm):
        query = urllib.parse.urlencode({'событие': event, 'луч': arm})
        return {'text': label, 'url': base.rstrip('/') + '/отклик?' + query}
    return {'chat_id': chat, 'text': 'One optional reflection: what supported you or needs one next step?',
            'reply_markup': {'inline_keyboard': [
                [button('resources', 'ресурсы'), button('past', 'прошлое')],
                [button('obligations', 'обязательства'), button('future', 'будущее')]]}}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--send', action='store_true', help='Deliver only after the owner authorizes this exact message')
    a = p.parse_args()
    value = payload(os.environ.get('KREST_PRIVATE_URL', 'https://private.example.invalid'),
                    os.environ.get('KREST_CHAT_ID', 'YOUR_CHAT_ID'), 'Personal reflection')
    if not a.send:
        print(json.dumps(value, ensure_ascii=False, indent=2)); return
    token = os.environ.get('KREST_BOT_TOKEN', '')
    if not token or value['chat_id'] == 'YOUR_CHAT_ID' or '.invalid' in os.environ.get('KREST_PRIVATE_URL', ''):
        raise SystemExit('Set your own token, chat and private HTTPS board URL first')
    request = urllib.request.Request('https://api.telegram.org/bot' + token + '/sendMessage',
                                     json.dumps(value).encode(), {'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            result = json.load(response)
        if not result.get('ok'): raise ValueError('Delivery rejected')
    except Exception:
        raise SystemExit('Delivery failed; inspect your private bot configuration (credentials omitted)') from None
    print('Delivered one owner-authorized ritual message')


if __name__ == '__main__': main()
