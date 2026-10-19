# Krest method – v2

Krest is an experimental day-planning and reflection instrument. It combines recorded context with deliberate personal input.

## Four directions

- **Obligations:** a commitment, deadline or scheduled demand. Ask what is yours and what can be completed or renegotiated.
- **Resources:** available time, practical support or an explicitly entered resource. Ask what can support one next step.
- **Past:** elapsed scheduled time or a recorded experience. An elapsed event does not establish attendance, success or completion.
- **Future:** a plan, possibility or concern. Ask which alternatives are plausible and which action is within your control.

Source adapters create versioned records with identity, origin, time and a declared weight. Calendar load is a planning heuristic. Native calendar mode assigns one point to a timed event, 1.5 above 90 minutes, and transfers scheduled weight from remaining to elapsed as time passes. Free-time estimation merges overlapping busy intervals inside the remaining local 09:00–19:00 window. All-day and declined entries are excluded. Calendar Control source selection is respected. A missing, stale or incomplete calendar cannot establish free time.

The private board can use additional source scales. Inspect its rules and source receipts before comparing it with the local calendar estimate. Counts are records, rather than verified promises per call. Public example data is fictional.

For a board snapshot, each arm sums its declared record weights. With `S = max(1, sum(abs(arm total)) / 2)`, the dot uses `x = (Future − Past) / S` and `y = (Resources − Obligations) / S`, clipped to −1…+1. A record's receipt separates base weight, source scale, time decay and any manual override. A scope-based time estimate is labelled as an estimate. These choices explain the picture; they do not measure the intensity of an experience.

## Feeling and energy

A check-in is voluntary and asks two separate questions:

1. **How does it feel?** Very unpleasant (−2), unpleasant (−1), neutral (0), pleasant (+1), very pleasant (+2).
2. **What happened to your energy?** Much lower (−2), lower (−1), unchanged (0), higher (+1), much higher (+2), compared with just before the event.

The current form saves both ratings together. Both initially display 0; saving confirms the displayed values. Review both before saving. Closing or skipping leaves the event unrecorded. The current schema has no separate missing value for one rating.

This is a custom personal-report interface. It is not a validated clinical instrument. It records the time of the answer, which matters when an event is rated retrospectively. An average describes the entries a person chose to save and may be biased by which events they rated. An edit replaces the earlier rating for that occurrence; this is a current-entry journal, rather than a sequence of repeated measurements.

The form uses an event's identity and scheduled start/end to attach your answer. Saving stores those fields, the answer time, both ratings and an optional sentence of up to 280 characters. It does not read a transcript, infer an emotion, collect another source, edit a calendar or change the source weights. Mac/board sync exchanges this journal separately; the fictional demo keeps it in the browser. See the [data flow and exact boundaries](DATA-FLOW.md).

## Reframing

Review the four questions, write another plausible perspective or one practical next step, and revisit it later. Original events and obligations remain intact. Keeping the original interpretation, accepting a difficult experience or choosing practical action are valid outcomes.

The research workspace offers temporary previews for a block, a direction or all records. A visible adjustable multiplier starts at 0.25. The calculation holds the observed snapshot's normalization constant while changing the selected weights; changing every weight therefore moves the illustrative position toward the centre. Source records remain unchanged. **The multiplier illustrates a thought experiment.** The four-arm construct, its weights, that multiplier and the old 26-second recoil have no established psychological calibration. The current workspace has no automatic evening flip or forced recoil. The private server retains the historical instrument under `/classic`; its animations do not establish effects on a person.

## Evidence and limits

Ecological momentary assessment literature supports careful attention to timing, burden and missingness. It does not validate Krest or permit a calendar-event sample to represent someone's whole emotional life. See the [Dutch EMA study](https://doi.org/10.3390/jcm9020322), [event-triggered versus random sampling](https://pmc.ncbi.nlm.nih.gov/articles/PMC7928529/) and [EMOWI instrument study](https://pmc.ncbi.nlm.nih.gov/articles/PMC8739680/).

Reappraisal research studies specific strategies in specific settings. Results depend on context and differ from acceptance or practical action. It provides a reason to offer an optional writing prompt, not a claim of lasting product benefit. See [reappraisal experiments](https://pubmed.ncbi.nlm.nih.gov/21999941/), [acceptance versus reappraisal](https://pmc.ncbi.nlm.nih.gov/articles/PMC6188704/) and [stressor controllability](https://www.psychologicalscience.org/journals/psychological-science/0956797613496434/).

The full source ledger is in [RESEARCH-2026-10-16.md](RESEARCH-2026-10-16.md). Project/vendor documentation is primary evidence of what those projects state, with interested provenance. Academic findings are bounded by populations and protocols. None evaluates Krest itself.
