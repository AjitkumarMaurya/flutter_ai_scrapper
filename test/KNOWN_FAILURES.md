# Known test failures

7 tests fail on the inherited `flutter_scrapper` 1.1.0 code. All 7 failed **identically before
and after** the Phase 0 restructure, which is the evidence that Phase 0 changed no behaviour.

**Every one is deferred, none is "fixed now."** Each failure traces back to the regex-based
parsing engine that Phase 1 deletes outright. Patching them with more regex would mean writing
code that gets thrown away days later — and in three cases the failing test is *correct* and the
library is wrong, so the fix belongs with the rewrite that makes it possible.

Delete an entry from this file only when its owning task makes the test pass for the right reason.

---

## Genuine library defects — Phase 1 fixes these

### 1. Attribute captures run past their closing quote

`real_website_simulation_test.dart` › *Portfolio Website Tests should extract contact information
and links*

```
Expected: contains 'https://example.com/in/johndesigner'
Actual:   ['https://example.com/project1.jpg"',      ← trailing quote
           'https://example.com/in/johndesigner</p>'] ← trailing markup
```

The capture does not stop at the attribute boundary, so closing quotes and following markup are
swallowed into the value. **The test is right; the library is wrong.** This is the same class of
defect as the confirmed BUG-1/BUG-2 — regex has no concept of where an attribute ends.

**Owner:** P1.1 (DOM parser) + P1.2 (BUG-1/BUG-2)

---

### 2. Greedy matching over-counts repeated blocks

`real_website_simulation_test.dart` › *E-commerce Website Tests should extract customer reviews
using regex*

```
Expected: <2>
Actual:   <5>
```

Direct evidence of the confirmed nested-tag defect: `(.*?)` cannot pair an opening tag with its
*matching* close, so repeated review blocks are mis-segmented.

**Owner:** P1.2 (BUG-1)

---

### 3. Requesting a non-existent capture group throws the wrong exception

`complex_edge_case_test.dart` › *Error Generation and Edge Case Tests should handle extremely long
regex patterns without crashing*

```
Expected: return normally
Actual:   threw ParseException: Failed to parse HTML with regex pattern:
          (?:(?:[a-zA-Z0-9._%+-]+@…)|…|(?:🚀|🤖|💰|📊|🔗))
```

> **New finding, discovered during Phase 0 — not in the original audit.**

Every group in that pattern is non-capturing (`(?:…)`), so there is no group 1. But
`queryWithRegex` defaults to `group: 1` and calls `match.group(1)` unconditionally, which throws a
`RangeError` that the broad `catch (e)` then relabels as a `ParseException` about failed parsing.
The diagnosis the user receives points at the wrong thing entirely.

Two things are wrong and both need fixing:

- A group index outside the pattern's range is a **caller error** and should raise
  `InvalidParameterException` naming the index and the group count — not a parse failure.
- When a pattern has no capture groups at all, `group: 0` (the whole match) is the only sensible
  default. Defaulting to 1 makes every group-less pattern fail.

**Owner:** P1.2 — tracked as **BUG-5**, added to `TASKS.md`

---

## Unspecified behaviour — decide, then encode

These two tests assert behaviour the library never actually promised. The failure is a missing
decision, not a broken implementation, so the fix is to choose the contract and then write it into
both the code and the test.

### 4. Which malformed patterns must throw?

`complex_edge_case_test.dart` › *should handle invalid regex patterns gracefully*

```
Expected: throws <Exception>
Actual:   returned <null>
```

The test assumes every malformed pattern is rejected, but Dart's `RegExp` accepts several that
look invalid to a human (`[unclosed bracket` throws; others do not). The library cannot promise
more than the underlying engine does.

**Decision needed:** validate patterns up front and reject a documented set, or state plainly that
pattern validity is `RegExp`'s contract and not ours. Prefer the second — inventing a stricter
dialect than Dart's would surprise people.

**Owner:** P1.6 (error model)

---

### 5. Is empty content "loaded"?

`complex_edge_case_test.dart` › *should handle empty and null content gracefully*

```
Expected: throws <ScraperNotInitializedException>
Actual:   returned <null>
```

After loading a page whose body is `''`, `_htmlContent` is empty-but-non-null, so the not-loaded
guard never fires. The test expects empty to count as not-loaded.

**Decision needed:** an empty response is a *successful fetch of an empty document* and should
query cleanly to empty results — that is the honest model. `ScraperNotInitializedException` should
mean only "you never called `load()`". Encode that and amend the test.

**Owner:** P1.6 (error model)

---

## Extraction quality — Phase 2 addresses these

Both are the heuristic extractors falling short. Neither survives contact with the structured-data
and normalisation work, so fixing the heuristics now would be wasted effort.

### 6. Contact-information extraction returns nothing

`complex_edge_case_test.dart` › *should extract complex contact information with multiple formats*
— `Expected: >= 3, Actual: 0`.

Related to the audited phone-number regex, which is simultaneously too loose (matches dates, SKUs,
IDs) and too rigid to handle real-world formatting variety.

**Owner:** P2.6 (drop or replace the phone regex) → P6.1 (`phone_normalizer`, E.164)

### 7. Financial data extraction under-counts

`complex_edge_case_test.dart` › *should extract cryptocurrency and financial data* —
`Expected: >= 3, Actual: 2`.

Same root cause as the audited currency defect: `extractPrices` assumes a single currency shape
and stamps `$` on everything it finds.

**Owner:** P2.6 (real currency detection) → P6.1 (`money_normalizer`)
