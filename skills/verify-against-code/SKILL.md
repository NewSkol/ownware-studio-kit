---
name: verify-against-code
description: Check whether a claim about a system is actually true by reading the source and running it, rather than trusting a summary, a comment, a README or a previous agent's report. Use when asked "is that actually true", "verify this", "did it really work", "prove it", "check what the code does", or whenever an agent or document says something is done and the evidence is a description rather than an execution.
---

# Verify against code

The common problem is not an AI that fails; it is an AI that reports success. A project can
have hundreds of passing tests and still not run once for real.
This skill exists to close the gap between *written* and *works*.

## The rule

**A claim is unverified until you have either read the line of code that implements it or
watched it run.** A comment, a README, a CHANGELOG, a test name, or another agent's summary
is not evidence. When code and documentation disagree, the code is the answer.

## Procedure

1. **State the claim in one falsifiable sentence.** "The importer skips already-imported
   transcripts" — not "the importer works". If it cannot be phrased so it could be wrong,
   it cannot be verified.

2. **Find the implementation.** Grep for the behaviour, not the word. Report the location as
   `file.ts:142` so the user can click it. If you cannot find code that implements the claim,
   that is the finding — stop there and say so.

3. **Read the surrounding branch, not just the matching line.** The common failure is a
   function that does the right thing on one path and silently does nothing on another.
   Ask: what inputs reach the `else`?

4. **Run it.** Preference order:
   - the real command with `--dry-run` or a read-only flag;
   - the real command against throwaway data;
   - the existing test, *executed*, with its output pasted — never "the tests cover this".
   If nothing can be run, say the claim is **reasoned, not verified**, and say why.

5. **Distrust a measurement that agrees with you.** If the check keeps confirming your
   hypothesis, suspect the check — especially one that pattern-matches a string you wrote
   (`pgrep -f`, grepping logs for a word you chose). Switch to a source that owns the answer.

6. **Never loosen the checker.** If a test or validator flags the claim as false, fix what it
   found. Relaxing the assertion to make it pass is the one move that is always wrong.

## Reporting

Three lines per claim, in the standing answer shape:

| | |
|---|---|
| **Claim** | what was asserted, and by whom |
| **Verdict** | TRUE / FALSE / UNVERIFIABLE — plus how it was established (read / ran / both) |
| **Evidence** | `file.ts:142` and the actual command output, quoted |

Plain English in the verdict; the rigour goes into the checking, not the wording.
If several claims were made and only some were checked, say which were not — an unchecked
claim reported alongside verified ones inherits their credibility, which is exactly the
failure this skill exists to prevent.
