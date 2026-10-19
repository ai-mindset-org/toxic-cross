import datetime as dt
import json
from pathlib import Path
import tempfile
import unittest
from provenance import adapter_evidence, manual_evidence, weight_evidence, receipt, item_decay, atomic_json


class ProvenanceContract(unittest.TestCase):
    def test_manual_annotation_never_becomes_a_fresh_observation(self):
        item={'вес':5,'источник':'A conversation last month'}
        manual_evidence(item);weight_evidence(item,5)
        self.assertEqual(item['evidence']['kind'],'manual')
        self.assertIsNone(item['evidence']['observedAt'])
        self.assertIsNone(item['evidence']['sourceCapturedAt'])
        self.assertEqual(item['evidence']['weight']['base'],5)

    def test_alias_has_canonical_adapter_and_exact_weight_math(self):
        now=dt.datetime(2026,10,19,tzinfo=dt.timezone.utc)
        item={'вес':4,'источник':'resources-summary'}
        adapter_evidence(item,'vault',now)
        weight_evidence(item,4,4,0.5,override=3)
        self.assertEqual(item['evidence']['adapter'],'vault')
        self.assertIsNone(item['evidence']['sourceCapturedAt'])
        self.assertEqual(item['evidence']['weight'],{'base':4,'scale':4,'decay':0.5,'override':3})

    def test_checking_a_stale_snapshot_does_not_refresh_its_capture(self):
        now=dt.datetime(2026,10,19,tzinfo=dt.timezone.utc)
        old=now-dt.timedelta(hours=12)
        result={'статус':'quiet','capturedAt':old.isoformat(),'expiresAt':(old+dt.timedelta(hours=6)).isoformat()}
        value=receipt(result,now,3)
        self.assertEqual(value['checkedAt'],now.isoformat())
        self.assertEqual(value['capturedAt'],old.isoformat())
        self.assertLess(dt.datetime.fromisoformat(value['expiresAt']),now)

    def test_past_decay_and_atomic_private_output(self):
        rules={'охваты':{'недельное':{'полураспад_дней':7}}}
        now=dt.datetime(2026,10,19,tzinfo=dt.timezone.utc)
        self.assertAlmostEqual(item_decay({'луч':'прошлое','т_ч':168},rules,now),0.5)
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'context.json'
            atomic_json(path,{'fictional':True})
            self.assertEqual(json.loads(path.read_text()),{'fictional':True})
            self.assertEqual(path.stat().st_mode&0o777,0o600)
            self.assertEqual(len(list(Path(tmp).iterdir())),1)


if __name__=='__main__':unittest.main()
