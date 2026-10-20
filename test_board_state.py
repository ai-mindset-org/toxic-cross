"""Fictional fixtures only: reversible board writes and observation history."""
from copy import deepcopy
import datetime as dt
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
from board_state import BoardStore, StateUnreadable, board_key, read_board, write_board, MAX_CHANGES
from provenance import adapter_evidence, weight_evidence
import server
import test_server as server_tests


def item(id='one', source='tasks', arm='обязательства', weight=4, adapter='tasks'):
    row = {'id': id, 'источник': source, 'т': 'Fictional block', 'луч': arm, 'вес': weight, 'вес_база': weight}
    adapter_evidence(row, adapter, dt.datetime(2026, 10, 20, tzinfo=dt.timezone.utc))
    weight_evidence(row, weight)
    return row


def context(*items):
    value = {'собрано': '2026-10-20T10:00:00Z', 'день': [], 'источники': {},
             'лучи': {arm: {'элементы': []} for arm in ('обязательства', 'прошлое', 'ресурсы', 'будущее')}}
    for row in items: value['лучи'][row['луч']]['элементы'].append(deepcopy(row))
    return value


class BoardStateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        self.store = BoardStore(self.root)
    def tearDown(self): self.tmp.cleanup()

    def test_hide_undo_rebalances_and_leaves_input_and_source_files_immutable(self):
        source = self.root / 'fictional-source.json'; source.write_text('retained original')
        raw = context(item(), item('support', 'resources', 'ресурсы', 2))
        original = deepcopy(raw)
        with self.store.locked():
            active = self.store.projection(self.store.ingest(raw)); key = board_key(item())
            hidden = self.store.visibility(active, key, True)
            self.assertEqual(hidden['context']['лучи']['обязательства']['сумма'], 0)
            self.assertEqual(hidden['context']['баланс']['y'], 1)
            self.assertEqual(hidden['state']['hidden'][0]['record']['вес'], 4)
            restored = self.store.visibility(hidden['context'], key, False)
            self.assertEqual(restored['context']['баланс'], active['баланс'])
            self.assertEqual(restored['context']['лучи'], active['лучи'])
        self.assertEqual(raw, original); self.assertEqual(source.read_text(), 'retained original')
        self.assertEqual(self.store.path.stat().st_mode & 0o777, 0o600)

    def test_stable_across_arm_reorder_and_kind_source_adapter_collisions(self):
        rows = [item(), item(source='other'), item(adapter='other')]
        manual = item(); manual['evidence']['kind'] = 'manual'; rows.append(manual)
        self.assertEqual(len({board_key(row) for row in rows}), 4)
        state = self.store.ingest(context(*rows)); count = len(state['changes'])
        state = self.store.ingest(context(*reversed(rows))); self.assertEqual(len(state['changes']), count)
        moved = deepcopy(rows[0]); moved['луч'] = 'будущее'
        self.assertEqual(board_key(moved), board_key(rows[0]))
        state = self.store.ingest(context(moved, *rows[1:]))
        self.assertEqual(state['changes'][0]['kind'], 'changed')
        self.assertEqual(state['changes'][0]['beforeArm'], 'обязательства')
        self.assertEqual(state['changes'][0]['arm'], 'будущее')

    def test_hidden_survives_refresh_updated_record_and_upstream_removal(self):
        row = item(); state = self.store.ingest(context(row))
        self.store.visibility(self.store.projection(state), board_key(row), True)
        updated = item(weight=7); updated['т'] = 'Fictional edited source'
        state = self.store.ingest(context(updated))
        self.assertEqual(self.store.projection(state)['лучи']['обязательства']['штук'], 0)
        self.assertEqual(self.store.public(state)['hidden'][0]['record']['вес'], 7)
        self.assertEqual(state['changes'][0]['weightDelta'], 3)
        state = self.store.ingest(context())
        self.assertFalse(self.store.public(state)['hidden'][0]['present'])
        restored = self.store.visibility(self.store.projection(state), board_key(row), False)
        self.assertEqual(restored['context']['лучи']['обязательства']['штук'], 0)
        self.assertEqual(restored['state']['changes'][0]['weightDelta'], 0)

    def test_legacy_provenance_enrichment_preserves_hidden_and_stale_undo_key(self):
        legacy = item(); legacy.pop('evidence')
        state = self.store.ingest(context(legacy)); key = board_key(legacy)
        self.store.visibility(self.store.projection(state), key, True)
        state = self.store.ingest(context(item()))
        self.assertEqual(self.store.projection(state)['лучи']['обязательства']['штук'], 0)
        reply = self.store.visibility(self.store.projection(state), key, False)
        self.assertEqual(reply['context']['лучи']['обязательства']['штук'], 1)
        # Enrichment is ambiguous when multiple real adapter namespaces share the id.
        self.assertNotEqual(board_key(item()), board_key(item(adapter='other')))

    def test_repeated_reads_no_entries_observation_time_is_not_source_change(self):
        state = self.store.ingest(context(item())); count = len(state['changes'])
        row = item(); row['evidence']['observedAt'] = '2026-10-20T11:00:00Z'; row['поз'] = .8
        state = self.store.ingest(context(row)); self.assertEqual(len(state['changes']), count)
        row['вес'] = 3; row['evidence']['weight']['decay'] = .75
        state = self.store.ingest(context(row))
        self.assertEqual(state['changes'][0]['kind'], 'recalculated')
        self.assertEqual(state['changes'][0]['cause'], 'recalculation')
        self.assertEqual(state['changes'][0]['weightDelta'], -1)
        state = self.store.ingest(self.store.projection(state)); self.assertEqual(len(state['changes']), count + 1)

    def test_corrupt_preserved_validation_and_bounded_log(self):
        self.store.path.parent.mkdir(); self.store.path.write_text('{broken')
        with self.assertRaises(StateUnreadable): self.store.ingest(context(item()))
        self.assertEqual(self.store.path.read_text(), '{broken')
        self.store.path.unlink()
        with self.assertRaises(ValueError): self.store.ingest(context(item(weight=float('nan'))))
        state = self.store.ingest(context(item()))
        for number in range(MAX_CHANGES + 10): self.store.event(state, 'changed', board_key(item()), item(), item(weight=5))
        self.store.save(state); self.assertEqual(len(self.store.load()['changes']), MAX_CHANGES)

    def test_full_collector_retains_hidden_and_distinct_same_id_sources(self):
        origin = Path(__file__).parent
        for file in ('собрать.py', 'provenance.py', 'board_state.py', 'commitment_links.py', 'правила.json'):
            shutil.copyfile(origin / file, self.root / file)
        (self.root / 'источники').mkdir()
        manual = {'лучи': {'обязательства': {'элементы': [item(source='manual-A'), item(source='manual-B')]}}, 'день': []}
        (self.root / 'источники/ручное.local.json').write_text(json.dumps(manual))
        command = [sys.executable, str(self.root / 'собрать.py'), '--без', 'календарь_ics,задачи_json,отклики']
        for run in range(2):
            result = subprocess.run(command, cwd=self.root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            active = read_board(self.root)
            if run == 0:
                self.assertEqual(active['лучи']['обязательства']['штук'], 2)
                row = active['лучи']['обязательства']['элементы'][0]
                with self.store.locked(): self.store.visibility(active, row['boardKey'], True)
            else:
                self.assertEqual(active['лучи']['обязательства']['штук'], 1)
                self.assertEqual(active['boardState']['hiddenCount'], 1)
        self.assertEqual(json.loads((self.root / 'источники/ручное.local.json').read_text()), manual)


class BoardAPITests(unittest.TestCase):
    setUp = server_tests.PrivateAPITest.setUp
    tearDown = server_tests.PrivateAPITest.tearDown
    request_json = server_tests.PrivateAPITest.request_json
    post = server_tests.PrivateAPITest.post

    def test_roundtrip_origin_malformed_and_no_static_source_edits(self):
        path = self.folder / 'контекст.json'; path.write_text(json.dumps(context(item())))
        original = path.read_bytes()
        status, active = self.request_json('/%D0%BA%D0%BE%D0%BD%D1%82%D0%B5%D0%BA%D1%81%D1%82.json')
        self.assertEqual(status, 200); key = active['лучи']['обязательства']['элементы'][0]['boardKey']
        for body in ({'key': key, 'hidden': 1}, {'key': 'missing', 'hidden': True}, {'key': key, 'hidden': True, 'source': 'delete'}, []):
            self.assertEqual(self.post('/board/visibility', body), 400)
        self.assertEqual(self.post('/board/visibility', {'key': key, 'hidden': True}, 'https://other.example'), 403)
        status, result = self.request_json('/board/visibility', {'key': key, 'hidden': True})
        self.assertEqual(status, 200); self.assertEqual(result['context']['лучи']['обязательства']['штук'], 0)
        self.assertEqual(self.request_json('/board-state')[1]['hidden'][0]['key'], key)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.request_json('/%D0%B4%D0%B5%D0%BD%D1%8C.json')[1]['лучи']['обязательства']['штук'], 0)
        self.assertEqual(self.request_json('/board/visibility', {'key': key, 'hidden': False})[1]['context']['лучи']['обязательства']['сумма'], 4)

    def test_partial_calendar_keeps_hidden_noncalendar_and_hidden_calendar(self):
        row = item('meeting', 'календарь', adapter='календарь')
        raw = context(item(), row); path = self.folder / 'контекст.json'
        write_board(self.folder, raw, path)
        active = read_board(self.folder)
        for record in active['лучи']['обязательства']['элементы']:
            self.request_json('/board/visibility', {'key': record['boardKey'], 'hidden': True})
        rules = {'источники': {}, 'охваты': {'недельное': {'полураспад_дней': 7, 'толщина': 10}}}
        (self.folder/'адаптеры').mkdir()
        (self.folder/'адаптеры/календарь.py').touch()
        (self.folder / 'правила.json').write_text(json.dumps(rules))
        adapter = types.SimpleNamespace(собрать=lambda *args: {'статус': 'live', 'элементы': [row], 'события': []})
        handler = object.__new__(server.Рук)
        original_import = server.importlib.import_module
        with patch.object(server.importlib, 'import_module', side_effect=lambda name, package=None: adapter if name.startswith('адаптеры.') else original_import(name, package)): handler.refresh_calendar()
        active = read_board(self.folder)
        self.assertEqual(active['лучи']['обязательства']['штук'], 0)
        state = read_board(self.folder, state_only=True)
        self.assertEqual(len(state['hidden']), 2)
        self.assertTrue(all(value['present'] for value in state['hidden']))
        self.assertEqual(len(BoardStore(self.folder).load()['snapshot']['лучи']['обязательства']['элементы']), 2)

    def test_corrupt_store_returns_503_and_is_preserved(self):
        (self.folder / 'день.json').write_text(json.dumps(context(item())))
        store = BoardStore(self.folder); store.path.parent.mkdir(); store.path.write_text('{broken')
        self.assertEqual(self.request_json('/board-state')[0], 503)
        self.assertEqual(self.post('/board/visibility', {'key': board_key(item()), 'hidden': True}), 503)
        self.assertEqual(store.path.read_text(), '{broken')


if __name__ == '__main__': unittest.main()
