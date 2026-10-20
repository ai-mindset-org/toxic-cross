# Commitment evidence contract

The board distinguishes a source observation, a suggested action and a confirmed commitment. A promise registry is an extraction ledger. Assignment, age, an approximate date or task completion alone does not establish a confirmed personal obligation or its fulfilment.

An adapter may attach `references` to a record:

```json
{
  "references": [
    {"kind": "source", "label": "Original meeting", "url": "https://example.test/meeting"},
    {"kind": "registry", "label": "Open registry", "id": "fictional-promise", "url": "https://example.test/registry#fictional-promise"}
  ]
}
```

The detail drawer renders only explicit HTTP(S) references, without embedded credentials or whitespace. It deduplicates URLs and uses `noopener noreferrer`. Paths without a URL remain visible text; the browser does not guess an opener or send a request automatically.

When explicit provenance establishes that multiple observations concern the same commitment, the counted representative may carry this explanation:

```json
{
  "commitment": {
    "canonicalId": "fictional-commitment",
    "policy": "One representative weight",
    "reason": "Explicitly linked synthetic evidence.",
    "inputs": [
      {"source": "tasks", "id": "DEMO-1", "weight": 3, "representative": true},
      {"source": "promises", "id": "fictional-promise", "weight": 2}
    ]
  }
}
```

This metadata explains a collector's result; it does not itself merge records or alter weights. The collector must establish identity using explicit stable identifiers and an evidenced relation. A shared title or meeting name is insufficient. A reference to the same task may describe several distinct commitments; ambiguous relationships require review. Source tests must demonstrate that a linked promise, task and accepted focus are not summed as three independent obligations.

Full promise IDs, capture time, owner attribution, review state, date precision and source references must survive the private normalization step. Uncertain ownership and machine extraction remain explicit. Approximate date ranges remain ranges. A late date or wording that sounds completed never triggers automatic closure or a psychological interpretation.

Private deployments retain raw extracts and owner mappings outside public Git. Public tests and screenshots use synthetic data only. Collection continues through the deployment's existing source pipeline and scheduler.
