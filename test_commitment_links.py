from copy import deepcopy
import unittest
from commitment_links import consolidate_focus


class ExplicitFocusLinks(unittest.TestCase):
    def row(self, ident, source, weight=2, **extra):
        return {'id': ident, 'источник': source, 'evidence': {'adapter': source}, 'вес': weight, 'луч': 'обязательства', **extra}

    def test_accepted_focus_counts_exact_linear_once_and_preserves_override(self):
        rows = [self.row('DEMO-1', 'linear', 7, вес_рука=7), self.row('focus-DEMO-1', 'фокус', accepted=True)]
        original = deepcopy(rows)
        out, aliases = consolidate_focus(rows)
        self.assertEqual(rows, original)
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0]['вес'], 7)
        self.assertEqual(out[0]['commitment']['inputs'][1]['weight'], 2)
        self.assertFalse(out[0]['commitment']['inputs'][1]['representative'])
        self.assertEqual(aliases, {'focus-DEMO-1': 'DEMO-1'})

    def test_similar_title_unconfirmed_and_different_ids_do_not_merge(self):
        rows = [self.row('DEMO-1', 'linear', т='Same words'),
                self.row('focus-DEMO-2', 'фокус', accepted=True, т='Same words'),
                self.row('focus-DEMO-1', 'фокус', accepted=False),
                self.row('DEMO-1', 'manual', т='Same words')]
        self.assertEqual(consolidate_focus(rows), (rows, {}))

    def test_ambiguous_focus_or_linear_identity_is_not_silently_merged(self):
        focus = self.row('focus-DEMO-1', 'фокус', accepted=True)
        issue = self.row('DEMO-1', 'linear')
        for rows in ([issue, focus, deepcopy(focus)], [issue, deepcopy(issue), focus]):
            self.assertEqual(consolidate_focus(rows), (rows, {}))

    def test_reference_without_active_linear_has_its_own_weight(self):
        row = self.row('focus-DEMO-1', 'фокус', accepted=True)
        self.assertEqual(consolidate_focus([row]), ([row], {}))


if __name__ == '__main__': unittest.main()
