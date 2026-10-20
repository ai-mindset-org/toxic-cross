"""Fictional full/partial calendar regression; no personal files or connectors."""
from copy import deepcopy
import datetime as dt
import importlib
import json
from pathlib import Path
import runpy
import shutil
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
from board_state import BoardStore, board_key, read_board
from provenance import calendar_adapter
from test_board_state import item, context
import server


class JournalNoiseTests(unittest.TestCase):
    def test_render_enrichment_and_zero_rounded_calendar_weight_are_quiet(self):
        with tempfile.TemporaryDirectory() as folder:
            store = BoardStore(folder)
            before = item('meeting', 'календарь', weight=1, adapter='календарь')
            state = store.ingest(context(before)); revision = state['revision']
            after = deepcopy(before)
            after.update(толщина=6, исключён_сегодня=False, ч=9.23, поз=.25)
            after['evidence']['observedAt'] = '2026-10-20T11:00:00Z'
            after['вес_база'] = 1.001
            after['evidence']['weight']['base'] = 1.001
            state = store.ingest(context(after))
            self.assertEqual(state['revision'], revision)
            self.assertEqual(store.load()['snapshot']['лучи']['обязательства']['элементы'][0]['ч'], 9.23)
            after['вес'] = .99
            state = store.ingest(context(after))
            self.assertEqual(state['revision'], revision + 1)
            self.assertEqual(state['changes'][0]['weightDelta'], -.01)
            self.assertEqual(state['changes'][0]['cause'], 'recalculation')

    def test_same_weight_keeps_source_arm_time_and_manual_offset_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            store = BoardStore(folder)
            row = item('meeting', 'календарь', adapter='календарь')
            row['start'] = '2026-10-20T09:00:00Z'; row['когда'] = row['start']
            state = store.ingest(context(row)); revision = state['revision']
            row['т'] = 'Fictional title edited'
            state = store.ingest(context(row)); self.assertEqual(state['revision'], revision + 1)
            row['луч'] = 'прошлое'
            state = store.ingest(context(row)); self.assertEqual(state['revision'], revision + 2)
            # Keep the occurrence ID; a changed recorded time is meaningful even at equal weight.
            row['когда'] = '2026-10-20T10:00:00Z'
            state = store.ingest(context(row)); self.assertEqual(state['revision'], revision + 3)
            manual = item(); manual['evidence']['kind'] = 'manual'
            manual['evidence']['time']['basis'] = 'source-offset'; manual['т_ч'] = 24
            state = store.ingest(context(manual)); revision = state['revision']
            manual['т_ч'] = 72
            state = store.ingest(context(manual)); self.assertEqual(state['revision'], revision + 1)


class CalendarCollectionTests(unittest.TestCase):
    def test_full_partial_repeat_same_model_provenance_override_position_and_revision(self):
        fixed = dt.datetime(2026, 10, 20, 12, 0, tzinfo=dt.timezone.utc)
        class FrozenClock(dt.datetime):
            @classmethod
            def now(cls, tz=None): return fixed.astimezone(tz) if tz else fixed.replace(tzinfo=None)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); original = Path(__file__).parent
            for name in ('собрать.py', 'provenance.py', 'board_state.py', 'commitment_links.py', 'правила.json'):
                shutil.copyfile(original / name, root / name)
            sources = root / 'источники'; sources.mkdir()
            adapters = root / 'адаптеры'; adapters.mkdir()
            (adapters / 'календарь.py').touch(); (adapters / 'calendar_bridge.py').touch()
            (sources / 'calendar-control.json').write_text('{}')
            (sources / 'ручное.local.json').write_text(json.dumps({'лучи': {}, 'день': []}))
            overrides = {'правки': [{'id': 'r-free', 'вес': 16, 'когда': '2026-10-19T10:00:00Z'}]}
            (sources / 'правки.json').write_text(json.dumps(overrides))
            rows = [item('meeting', 'календарь', weight=1, adapter='календарь'),
                    item('r-free', 'ресурсы-авто', 'ресурсы', 1.9, adapter='календарь')]
            for row in rows: row.pop('evidence'); row['охват'] = 'ситуативное'
            result = {'статус': 'live', 'элементы': rows, 'события': [], 'capturedAt': fixed.isoformat()}
            adapter = types.SimpleNamespace(собрать=lambda *args: deepcopy(result))
            imported = []
            original_import = importlib.import_module
            def resolve(name, package=None):
                if not name.startswith('адаптеры.'): return original_import(name, package)
                imported.append(name)
                self.assertEqual(name, 'адаптеры.календарь')
                return adapter
            self.assertEqual(calendar_adapter(root), 'календарь')
            with patch.object(dt, 'datetime', FrozenClock), patch.object(importlib, 'import_module', side_effect=resolve), patch.object(sys, 'argv', ['собрать.py', '--без', 'задачи_json,отклики']), patch.object(server, 'КОРЕНЬ', root):
                runpy.run_path(str(root / 'собрать.py'), run_name='__main__')
                store = BoardStore(root); full = store.load(); revision = full['revision']
                free = full['snapshot']['лучи']['ресурсы']['элементы'][0]
                self.assertEqual(free['вес'], 16)
                self.assertEqual(free['evidence']['weight']['override'], 16)
                expected_balance = read_board(root)['баланс']
                handler = object.__new__(server.Рук)
                for _ in range(2):
                    handler.refresh_calendar()
                    current = store.load()
                    self.assertEqual(current['snapshot']['лучи'], full['snapshot']['лучи'])
                    self.assertEqual(current['revision'], revision)
                    self.assertEqual(current['snapshot']['правила_версия'], full['snapshot']['правила_версия'])
                    self.assertEqual(read_board(root)['баланс'], expected_balance)
                self.assertEqual(imported, ['адаптеры.календарь'] * 3)
            self.assertEqual(json.loads((sources / 'правки.json').read_text()), overrides)


if __name__ == '__main__': unittest.main()
