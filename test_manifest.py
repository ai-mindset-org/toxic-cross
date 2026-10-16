import hashlib
import json
from pathlib import Path
import unittest

class ComponentProvenance(unittest.TestCase):
    def test_generated_receipt_matches_exact_vendored_sources(self):
        root=Path(__file__).parent/'native'
        receipt=json.loads((root/'assets/design-receipt.json').read_text())
        for name,digest in receipt['files'].items():
            self.assertRegex(digest,r'^[a-f0-9]{64}$')
            self.assertEqual(hashlib.sha256((root/'swift'/name).read_bytes()).hexdigest(),digest,name)

if __name__=='__main__':unittest.main()
