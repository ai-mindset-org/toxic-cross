import datetime as dt
from copy import deepcopy
import unittest
from commitment_links import consolidate_commitments
from promise_projection import annotate_influence, project_promises

NOW = dt.datetime(2026, 10, 20, 12, tzinfo=dt.timezone.utc)


def record(ident='fictional-one', **extra):
    return {'id': ident, 'owner_id': 1, 'title': 'Synthetic action', 'status': 'open', 'kind': 'task',
            'confirmation': 'source-action-ledger', 'flags': [], 'chain_id': 'task:DEMO-1',
            'deadline': {'kind': 'unknown', 'label': 'Date unknown'}, 'linear_links': [], **extra}


def packet(rows):
    return {'schema_version': 1, 'observed': True, 'complete': True, 'source_last_success_at': '2026-10-20T11:00:00Z',
            'expires_at': '2026-10-20T17:00:00Z', 'records': rows, 'url': 'https://example.test/registry'}


class PromiseProjection(unittest.TestCase):
    def test_extractions_questions_closed_and_unknown_owner_are_not_scored(self):
        rows = [record('candidate', confirmation='machine-extracted'), record('question', kind='decision', flags=['not-commitment']),
                record('closed', status='closed'), record('claim', flags=['completion-claim']), record('missing', flags=['source-missing']), record('owner', owner_id=None)]
        result = project_promises(packet(rows), 1, NOW)
        self.assertEqual(result['элементы'], [])
        self.assertEqual(len(result['promiseRegistry']['records']), 5)
        self.assertEqual(rows[0]['status'], 'open', 'no source mutation')

    def test_window_is_not_invented_into_an_exact_due_date_or_overdue(self):
        row = record(deadline={'kind': 'window', 'window_start': '2026-10-12', 'window_end': '2026-10-18', 'window_elapsed': True, 'label': 'That week; exact day unspecified'})
        item = project_promises(packet([row]), 1, NOW)['элементы'][0]
        self.assertNotIn('срок', item)
        self.assertNotIn('т_ч', item)
        self.assertNotIn('просрочено', item)
        self.assertEqual(item['dueWindow']['window_end'], '2026-10-18')

    def test_fresh_source_and_exact_dates_are_separate_from_projection_time(self):
        p = packet([record(deadline={'kind': 'exact', 'date': '2026-10-19', 'overdue': True})])
        result = project_promises(p, 1, NOW)
        self.assertEqual(result['элементы'][0]['просрочено'], 1)
        self.assertEqual(result['capturedAt'], '2026-10-20T11:00:00+00:00')
        stale = project_promises(p, 1, NOW+dt.timedelta(hours=6))
        self.assertEqual(stale['элементы'], [])
        self.assertEqual(len(stale['promiseRegistry']['records']), 1)

    def test_reviewed_promise_focus_and_linear_have_one_weight(self):
        result = project_promises(packet([record()]), 1, NOW)
        rows = [dict(id='DEMO-1', источник='linear', вес=3, evidence={'adapter':'linear'}),
                dict(id='focus-DEMO-1', источник='фокус', вес=2, accepted=True, evidence={'adapter':'фокус'}),
                *result['элементы']]
        merged, aliases = consolidate_commitments(rows)
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]['вес'], 3)
        self.assertEqual(len(merged[0]['commitment']['inputs']), 3)
        registry = annotate_influence(result['promiseRegistry'], merged)
        self.assertEqual(registry['records'][0]['influence']['kind'], 'linked')
        self.assertEqual(registry['records'][0]['influence']['weight'], 0)
        self.assertEqual(aliases['focus-DEMO-1'], 'DEMO-1')

    def test_literal_linear_reference_is_not_an_equivalence_relation(self):
        result = project_promises(packet([record(chain_id='promise:fictional-one', linear_links=[{'id':'DEMO-1','url':'https://example.test/task'}])]), 1, NOW)
        task = dict(id='DEMO-1', источник='linear', вес=3, evidence={'adapter':'linear'})
        merged, _ = consolidate_commitments([task, *result['элементы']])
        self.assertEqual(len(merged), 2)

    def test_hidden_representative_has_no_registry_contribution(self):
        result = project_promises(packet([record()]), 1, NOW)
        row = result['элементы'][0]
        visible = annotate_influence(result['promiseRegistry'], [row])
        self.assertEqual(visible['records'][0]['influence']['weight'], 2)
        hidden = annotate_influence(visible, [], [row])
        self.assertEqual(hidden['records'][0]['influence']['kind'], 'hidden')
        self.assertEqual(hidden['records'][0]['influence']['weight'], 0)

    def test_existing_manual_weight_eligibility_survives_without_confirming_registry(self):
        row = record(confirmation='machine-extracted', chain_id='promise:fictional-one')
        result = project_promises(packet([row]), 1, NOW, {'p-fictional-': {'вес': 4}})
        self.assertEqual(len(result['элементы']), 1)
        self.assertEqual(result['элементы'][0]['confirmation'], 'machine-extracted')
        self.assertNotIn('taskIdentity', result['элементы'][0]['commitment'])

    def test_duplicate_source_ids_and_future_capture_are_rejected(self):
        with self.assertRaises(ValueError): project_promises(packet([record(), record()]), 1, NOW)
        p = packet([]); p['source_last_success_at'] = '2026-10-20T13:00:00Z'
        with self.assertRaises(ValueError): project_promises(p, 1, NOW)


if __name__ == '__main__': unittest.main()
