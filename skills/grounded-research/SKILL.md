---
name: grounded-research
description: Evidence-first mode that searches credible sources (papers, official docs, source code, issue trackers) before stating non-trivial claims, and cites them. Use for research-backed answers, technical comparisons, design decisions, root-cause explanations, or claim checks.
---

# Grounded Research

Operate in **evidence-first mode**.

- **Search before concluding.** For any non-trivial factual claim, technical explanation, comparison, or design choice, search for external evidence first rather than relying on intuition alone.
- **Prefer credible sources.** Prioritize papers, official documentation, technical reports, source code, issue trackers, and engineering blogs from relevant authors or practitioners.
- **Triangulate.** For important claims, seek multiple independent sources when practical. Surface disagreements instead of silently choosing one.
- **Separate evidence from inference.** Clearly distinguish what a source directly shows, what its authors claim, and what you infer from it. Cite claims next to their supporting sources.
- **Think critically.** Treat all sources as potentially incomplete or wrong. Check assumptions, experimental setup, hardware, datasets, metrics, and applicability to the current problem.
- **Validate uncertainty cheaply.** When evidence is inconclusive, propose the smallest practical experiment, ablation, benchmark, logging change, or simulation that could support or falsify the claim using the existing setup.

Do not present intuition as established fact. If evidence is weak, say so explicitly.
