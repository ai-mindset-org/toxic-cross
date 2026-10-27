"""Portable rules must affect source selection, weights and every rebalance."""
import datetime as dt
import json
from pathlib import Path
import tempfile
import unittest

from board_state import rebalance
from provenance import calendar_adapter, manual_evidence, prepare_weight


class ConfiguratorRules(unittest.TestCase):
    def test_explicit_calendar_selection_overrides_existing_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'источники').mkdir()
            (root / 'источники/calendar-control.json').write_text('{}')
            for bridge, expected in [(False, 'календарь_ics'), (True, 'calendar_bridge')]:
                (root / 'правила.json').write_text(json.dumps({'configurator': {'version': 1, 'enabled': {'bridge': bridge}}}))
                self.assertEqual(calendar_adapter(root), expected)

    def test_source_scope_and_multiplier_apply_before_decay(self):
        rules = {'configurator': {'version': 1}, 'охваты': {'недельное': {'полураспад_дней': 7}, 'глобальное': {'полураспад_дней': 45}},
                 'источники': {'ручное': {'масштаб': 2, 'охват': 'недельное'}}}
        item = {'вес': 8, 'источник': 'ручное', 'охват': 'глобальное', 'луч': 'прошлое', 'т_ч': -168}
        manual_evidence(item)
        prepare_weight(item, rules, dt.datetime.now(dt.timezone.utc))
        self.assertEqual(item['вес'], 8)
        self.assertEqual(item['охват'], 'недельное')
        self.assertEqual(item['evidence']['kind'], 'manual')
        self.assertEqual(item['evidence']['weight']['scale'], 2)
        self.assertEqual(item['evidence']['weight']['decay'], .5)

    def test_configured_signal_survives_board_recalculation(self):
        data = {'лучи': {arm: {'элементы': [{'вес': weight}]} for arm, weight in
                         [('обязательства', 5), ('ресурсы', 2), ('прошлое', 0), ('будущее', 0)]},
                'сигнал_множитель': 2}
        rebalance(data)
        self.assertTrue(data['сигнал'])
        data['сигнал_множитель'] = 3
        rebalance(data)
        self.assertFalse(data['сигнал'])


if __name__ == '__main__': unittest.main()
