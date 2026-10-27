# Krest method – v2

Krest is an experimental day-planning and reflection instrument. It combines recorded context with deliberate personal input.

## Origin and working sequence

The original four-direction practice asks a person to revisit commitments, evidence from past experience, available resources and plausible future scenarios together. The current product preserves those questions and offers an Overview, a Cross, explicit timelines and a source-change journal. The [2026-10-20 research update](RESEARCH-2026-10-20.md) compares the practice with cognitive formulation, demands/resources theory, implementation intentions and personal informatics.

Begin with the accepted plan and scheduled day. Inspect the source and time basis of a demand. Consider an available resource and concrete next step. Revisit the recorded result or add a voluntary check-in. The dot describes source arithmetic; a check-in records an experience at its own time.

## The original model and its adaptation

The [18 September 2026 post](https://t.me/ai_mind_set/375) describes a synthesis of **Beck’s cognitive triad**, **Lazarus’s appraisal of demands against resources** and **Hobfoll’s loss spiral**. This is the original model’s framing; those theories do not validate this four-arm instrument or its weights.

In that framing, obligations sit above (how many people are watching and what they expect), resources below (money, time and energy), past on the left (where something similar failed) and future on the right (a fan of bad scenarios). The instrument also allows practical observations, resources and possible next steps in those directions.

Each fact has a declared base weight, a source scale and time decay. Default half-lives are **1 day** for situational, **7 days** for weekly and **45 days** for global context. The conceptual upward balance is `(Future − Past, Obligations − Resources)`; screen coordinates invert the vertical axis and normalize the totals as described below. The default signal is obligations > `3 × max(1, resources)`; the floor prevents a zero-resource division/threshold edge. This is a source-weight heuristic.

Rename the four labels, choose sources and their scales, time horizons, half-lives and signal threshold in the [browser configurator](https://apps.aimindset.org/krest/build.html#configure), then connect one selected source. Inspect its source receipt and keep personal records private.

## Four directions

- **Obligations:** a commitment, deadline or scheduled demand. Ask what is yours and what can be completed or renegotiated.
- **Resources:** available time, practical support or an explicitly entered resource. Ask what can support one next step.
- **Past:** elapsed scheduled time or a recorded experience. An elapsed event does not establish attendance, success or completion.
- **Future:** a plan, possibility or concern. Ask which alternatives are plausible and which action is within your control.

Source adapters create versioned records with identity, origin, time and a declared weight. Calendar load is a planning heuristic. Native calendar mode assigns one point to a timed event, 1.5 above 90 minutes, and transfers scheduled weight from remaining to elapsed as time passes. Free-time estimation merges overlapping busy intervals inside the remaining local 09:00–19:00 window. All-day and declined entries are excluded. Calendar Control source selection is respected. A missing, stale or incomplete calendar cannot establish free time.

The private board can use additional source scales. Inspect its rules and source receipts before comparing it with the local calendar estimate. Counts describe source records. Per-call commitment counts require a separately verified source. Public example data is fictional.

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

The research workspace offers temporary previews for a block, a direction or all records. A visible adjustable multiplier starts at 0.25. The calculation holds the observed snapshot's normalization constant while changing the selected weights; changing every weight therefore moves the illustrative position toward the centre. Source records remain unchanged. **The multiplier illustrates a thought experiment.** The four-arm construct, its weights, that multiplier and the old 26-second recoil have no established psychological calibration. The private research workspace has no automatic evening flip or forced recoil. The landing’s separate **guided fictional demo** illustrates the historical rule: one arm starts at ×0.25, then neighbours return 75% of the removed weight linearly over 26 seconds (ending at ×0.8125); all four at ×0.25 hold until reset. Its arrows and timer are a visual explanation, with no psychological calibration. Changing a time window changes the visible records and axis of that arm while retaining the full snapshot balance. Source records are kept intact, and none of these actions writes personal data. The private server retains the historical instrument under `/classic`; its animations do not establish effects on a person.

## Evidence and limits

Ecological momentary assessment literature supports careful attention to timing, burden and missingness. It does not validate Krest or permit a calendar-event sample to represent someone's whole emotional life. See the [Dutch EMA study](https://doi.org/10.3390/jcm9020322), [event-triggered versus random sampling](https://pmc.ncbi.nlm.nih.gov/articles/PMC7928529/) and [EMOWI instrument study](https://pmc.ncbi.nlm.nih.gov/articles/PMC8739680/).

Reappraisal research studies specific strategies in specific settings. Results depend on context and differ from acceptance or practical action. It provides a reason to offer an optional writing prompt, not a claim of lasting product benefit. See [reappraisal experiments](https://pubmed.ncbi.nlm.nih.gov/21999941/), [acceptance versus reappraisal](https://pmc.ncbi.nlm.nih.gov/articles/PMC6188704/) and [stressor controllability](https://www.psychologicalscience.org/journals/psychological-science/0956797613496434/).

The full source ledger is in [RESEARCH-2026-10-16.md](RESEARCH-2026-10-16.md). Project/vendor documentation is primary evidence of what those projects state, with interested provenance. Academic findings are bounded by populations and protocols. None evaluates Krest itself.

## Origin

The “toxic cross” model is [Vsevolod (Seva) Ustinov’s](https://t.me/vsevolodustinovchannel) idea, drawn during a conversation on 15 September 2026. The [18 September post](https://t.me/ai_mind_set/375) promised the code at 50 likes and received 106. After three versions over six weeks on live data, the open package followed on 27 October 2026. Krest is an attempt to test it hands-on.
