# Implementation Plan — Glassmorphic Share Cards

## Codebase Findings

### Files to modify
| File | Method | Lines |
|------|--------|-------|
| `lib/features/dashboard/dashboard_page.dart` | `_shareQuoteAsImage()` | 3104–3281 |
| `lib/features/quran/surah_reader_page.dart` | `_shareVersesAsImage()` | 2065–2323 |

### Imports already present in both files
| Import | dashboard_page.dart | surah_reader_page.dart |
|--------|---------------------|------------------------|
| `dart:io` | ✅ line 1 | ✅ line 1 |
| `dart:ui as ui` | ✅ line 3 | ✅ line 4 |
| `package:flutter/rendering.dart` | ✅ | ✅ |
| `package:google_fonts/google_fonts.dart` | ✅ | ✅ |
| `package:share_plus/share_plus.dart` | ✅ | ✅ |
| `package:path_provider/path_provider.dart` | ✅ | ✅ |
| `../../core/app_colors.dart` | ✅ | ✅ |

**No new imports are needed in either file.**

### AppColors constants confirmed in `lib/core/app_colors.dart`
```dart
AppColors.darkGreen   = Color(0xFF1B7A4E)   // mid-green, used as accent tint
AppColors.midGreen    = Color(0xFF34A56F)
AppColors.lightGreen  = Color(0xFF6FCF97)
AppColors.paleGreen   = Color(0xFFE8F8EF)
AppColors.background  = Color(0xFFFAFDFB)
AppColors.cardBg      = Color(0xFFFFFFFF)   // white — do NOT use as dark glass bg
AppColors.surfaceLight = Color(0xFFF4F9F6)
AppColors.gold        = Color(0xFFD4A843)
AppColors.goldLight   = Color(0xFFFDF3D7)
AppColors.goldBg      = Color(0xFFFFFBF0)
AppColors.gray        = Color(0xFF8E99A4)
AppColors.grayLight   = Color(0xFFEEF1F4)
AppColors.dark        = Color(0xFF2C3E50)
AppColors.textPrimary  = Color(0xFF1E293B)
AppColors.textSecondary = Color(0xFF64748B)
```

**There is no `AppColors.darkBackground` or similar dark-green background constant.**
The existing glassmorphic designs hard-code dark hex values like `Color(0xFF091610)` / `Color(0xFF132B1F)` directly — follow the same pattern.

### Existing glassmorphic patterns to follow
Both `_sharePartialAsImage` (surah_reader, line 1834) and `_shareAsImage` (surah_reader, line 3283) are already glassmorphic. The pattern used in `_sharePartialAsImage` is the target style for `_shareVersesAsImage`:

```
ClipRRect(borderRadius: 20)
  Stack
    Positioned.fill → Container(dark gradient)         // opaque base
    Positioned.fill → BackdropFilter(blur σ=8) + tint  // glass layer
    Container(border: gold, borderRadius: 20)           // content frame
      Column(header badge / text / divider / branding)
```

The dashboard quote card already uses a plain gradient `Container` — replace it with the same `ClipRRect + Stack` pattern.

### Helper function `_f()`
`_f({sz, fw, c, h})` is a **file-level** `TextStyle` function in `dashboard_page.dart` (line 58). It is **not** in surah_reader_page. Keep using `_f()` for all Text styles in the dashboard card; use `GoogleFonts.ibmPlexSansArabic()` / `GoogleFonts.amiri()` directly in surah_reader.

---

## Risks & Gotchas

1. **`withOpacity` vs `withValues`** — the codebase consistently uses `.withValues(alpha: x)` (the modern Flutter API). Never write `.withOpacity(x)`; it will produce an analyzer warning and may behave differently with wide-gamut color spaces.

2. **`BackdropFilter` inside a dialog renders as a black box on some Android API levels** — the existing `_sharePartialAsImage` already uses it inside an AlertDialog and ships fine. The same pattern is safe to replicate.

3. **RepaintBoundary captures exactly its child widget tree.** `BackdropFilter` inside `RepaintBoundary` blurs **the content below the RepaintBoundary itself in the compositor**, not the dialog background — when captured to PNG the blur has nothing to operate on and renders as a plain color. This is **expected behavior** (same as existing `_sharePartialAsImage`). The gradient base layer provides the visual depth; blur is a live-preview bonus only.

4. **`ClipRRect` as direct `RepaintBoundary` child** — the surah_reader design already wraps with `ClipRRect`; keep this. For the dashboard card, the new design must also wrap with `ClipRRect` so the rounded corners are captured correctly in the PNG. The current dashboard card uses `BoxDecoration(borderRadius: ...)` which does **not** clip child painting — moving to `ClipRRect` fixes a subtle corner-bleed bug in the captured image.

5. **`dart:ui as ui` alias** — both files already import with this alias. All references to `ui.ImageFilter.blur(...)`, `ui.Image`, and `ui.ImageByteFormat.png` must keep the `ui.` prefix.

6. **`isDark` variable in `_shareVersesAsImage`** — the variable is declared at line 2075 but the dark-mode check only controls the `AlertDialog.backgroundColor`. The glassmorphic card itself is always dark-on-dark; do not make the card conditional on `isDark` (matches the existing `_sharePartialAsImage` behavior).

7. **Width constraints** — `_shareVersesAsImage` uses `width: 360` on the content container inside the Stack. `_shareQuoteAsImage` uses `width: double.infinity`. Keep these widths; changing them would alter the captured PNG dimensions and could break Share sheet previews.

8. **Bottom action buttons are outside the RepaintBoundary** — they are not captured in the PNG. They must be re-styled to look consistent with the glassmorphic card, but style changes there carry zero risk to the image capture.

---

## Implementation Plan

- [ ] 1. **Replace the RepaintBoundary child in `_shareQuoteAsImage` (dashboard)**  
  Replace the plain gradient `Container` (direct child of `RepaintBoundary`, lines 3122–3214 in `dashboard_page.dart`) with a `ClipRRect + Stack` glassmorphic layout matching the `_sharePartialAsImage` pattern.  
  The new child is:
  ```
  ClipRRect(borderRadius: 28)
    Stack
      Positioned.fill → Container(dark diagonal gradient: 0xFF0D2818→0xFF145A3A→0xFF0A2013)
      Positioned.fill → BackdropFilter(blur σ=8) + Colors.white.withValues(alpha:0.04) tint
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(28),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold.withValues(alpha:0.6), width: 1.5),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(...)   // same quote content as today, unchanged
      )
  ```
  Keep every widget inside `Column(...)` **exactly as-is** — only wrap the outer container.  
  Files: `lib/features/dashboard/dashboard_page.dart`  
  Verify: `flutter build apk --debug` completes without errors; open the app → Dashboard → long-press a quote → share icon → dialog renders a dark glassmorphic card.

- [ ] 2. **Re-style the bottom action buttons in `_shareQuoteAsImage` (dashboard)**  
  The two buttons (`ElevatedButton.icon` "مشاركة البطاقة كصورة" and `TextButton` "إغلاق") are outside the RepaintBoundary (lines 3216–3278). Update their styling:
  - Wrap the `Row` in a `Container` with `decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16))` and `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)`.
  - `ElevatedButton.icon`: keep `backgroundColor: AppColors.gold`; add `elevation: 0` and `shadowColor: Colors.transparent`.
  - `TextButton` "إغلاق": change text color from `Colors.white` to `AppColors.gold.withValues(alpha: 0.85)`.  
  Files: `lib/features/dashboard/dashboard_page.dart`  
  Verify: same build + visual check; both buttons render on a frosted container below the card.

- [ ] 3. **Replace the RepaintBoundary child in `_shareVersesAsImage` (surah reader)**  
  The current `ClipRRect + Stack` at lines 2091–2222 in `surah_reader_page.dart` already uses a glassmorphic structure identical to `_sharePartialAsImage`. Compare the two side-by-side and bring `_shareVersesAsImage` to parity with the more refined `_shareAsImage` (line 3283) design:
  - Replace the dark gradient colors `[0xFF091610, 0xFF132B1F, 0xFF08120D]` (vertical) with the diagonal four-stop gradient from `_shareAsImage`: `[0xFF0B301D@0.94, 0xFF13482E@0.88, 0xFF1E5E3D@0.82, 0xFF0E2819@0.96]` using `begin: Alignment.topLeft, end: Alignment.bottomRight`.
  - Replace `BackdropFilter` blur-only glass layer with the same double-border `Positioned.fill` frame (inner gold border at `0xFFD4A843.withValues(alpha:0.6)` radius 20, inner-inner at alpha 0.25 radius 16) used in `_shareAsImage`.
  - Add `boxShadow` matching `_shareAsImage`: green glow `0xFF1B7A4E@0.3 blur=30` + black drop `Colors.black@0.5 blur=24 offset=(0,10)`.
  - Keep the existing content `Column` (surah badge, verse texts, verse number ornaments, divider, branding row) **unchanged**.  
  Files: `lib/features/quran/surah_reader_page.dart`  
  Verify: `flutter build apk --debug` passes; open app → Quran → select verses → share → dialog shows refined glassmorphic card.

- [ ] 4. **Re-style the bottom action buttons in `_shareVersesAsImage` (surah reader)**  
  The `Padding(padding: EdgeInsets.all(16)) → Row` at lines 2250–2322 contains "إلغاء" (`TextButton`) and "مشاركة" (`ElevatedButton.icon`). Update:
  - Wrap the `Padding → Row` in an additional `Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.25), borderRadius: BorderRadius.only(bottomLeft:20, bottomRight:20)))`.
  - `ElevatedButton.icon`: change `backgroundColor` from `AppColors.darkGreen` to `AppColors.gold`, `foregroundColor` from `Colors.white` to `Colors.black87`, add `elevation: 0`.
  - `TextButton` "إلغاء": change text color from `AppColors.textSecondary` / `Colors.white60` to `AppColors.gold.withValues(alpha:0.75)`.  
  Files: `lib/features/quran/surah_reader_page.dart`  
  Verify: build passes; bottom button strip looks cohesive with the dark card above.

- [ ] 5. **Final build & smoke test**  
  Run `flutter build apk --debug` from the workspace root. Confirm zero compilation errors.  
  Open the debug APK on a device/emulator:
  - Dashboard → long-press quote → share-as-image → verify glassmorphic card appears, gold border visible, PNG share produces the correct image.
  - Quran → open any surah → long-press verses → share → verify refined glassmorphic card and gold share button.  
  Files: none (verification only)  
  Verify: `flutter build apk --debug` exits 0; both dialogs render correctly at runtime.

---

## Implementation Order Rationale

Steps 1 and 3 are the structural replacements — they must be done before steps 2 and 4 (which depend on the containing widget tree being correct). Steps 1 and 3 are independent of each other and can be done in either order. Steps 2 and 4 each follow their respective structural step. Step 5 is the final gate.
