# Implementation Plan — UI/UX Revamp (Basair / NiyyahTracker)

12 UI/UX changes for the Flutter app at `e:/NiyyahTracker-mobile-app-ai`. All Dart/Flutter.
App conventions: `GoogleFonts.ibmPlexSansArabic` for UI text, `AppColors` constants
(`darkGreen=#1B7A4E`, `gold=#D4A843`, `midGreen`, `lightGreen`, `paleGreen`…), `Directionality.rtl`
throughout, dark/light aware via `Theme.of(context).brightness == Brightness.dark`.

Global verification gate: **`flutter analyze` must pass with no errors.**
(`flutter test` is NOT a gate — `test/widget_test.dart` is broken boilerplate that asserts a
counter "0" which this app never renders; it fails pre-existing. Do not "fix" it as part of this work.)
Run from repo root: `flutter analyze`.

Shared-file note: `dashboard_page.dart` is touched by tasks 1, 4, 5, 7, 10, 11, 6, 12 — all of
those are sequenced inside FEAT-003 (one coder owns the whole file) to avoid conflicts. The Quran
reader (tasks 2, 3, 9, + task 4's surah-share) is FEAT-001 (independent file cluster). The glassy
design system + prayer/azkar surfaces (tasks 7's reusable widget + 8) is FEAT-002. FEAT-003 depends
on FEAT-002's `GlassCard`.

---

## FEAT-001 — Quran reader revamp  (tasks 2, 9, 3, + 4-surah-share)

- [ ] 1. Fix the `DirectionalIcon` RTL bug in `lib/core/directional_icon.dart`.
      Both branches currently return the same icon. In RTL the back arrow must visually point right
      and the forward arrow left: set the RTL branch to
      `icon = isBack ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new;` (LTR branch stays
      `isBack ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios_rounded`). This fixes the header
      back button and the trailing arrow in `_actionTile`.
      Files: lib/core/directional_icon.dart
      Verify: `flutter analyze` — no errors.

- [ ] 2. Reverse the Quran reader footer navigation in `lib/features/quran/surah_reader_page.dart`
      `_buildFooter`. The footer `Row` (spaceBetween) has a left `_navBtn(Icons.chevron_left_rounded,
      canPrev, … animateToPage(_currentPage - 1))` and a right `_navBtn(Icons.chevron_right_rounded,
      canNext, … animateToPage(_currentPage + 1))`. For RTL Arabic reading the right button must go to
      the PREVIOUS page and the left button to the NEXT page. Swap the two `_navBtn` callbacks and
      their enable-flags: right button → `animateToPage(_currentPage - 1)` enabled `canPrev`; left
      button → `animateToPage(_currentPage + 1)` enabled `canNext`. Keep the chevron icons in place
      (right chevron pointing right now correctly means "previous"; left chevron means "next").
      Files: lib/features/quran/surah_reader_page.dart
      Verify: `flutter analyze` — no errors. Open a surah: right footer chevron goes to the previous
      page, left chevron to the next.

- [ ] 3. Fix "آل عمران" header overflow in `_buildHeader` of the same file. The header `Row`
      (spaceBetween) holds the back button, the surah-name `Text(quran.getSurahNameArabic(s))`, "Juz",
      "Hizb", audio/count/wird/bookmark/settings buttons — the surah name is unconstrained and clips
      on long names. Wrap that `Text` in `Flexible(child: Text(…, maxLines: 1,
      overflow: TextOverflow.ellipsis, …))` (keep the existing fontFamily/fontSize logic).
      Files: lib/features/quran/surah_reader_page.dart
      Verify: `flutter analyze` — no errors. Open surah 3 (آل عمران): the name no longer overflows.

- [ ] 4. Make the shared-verse images glassy (task 4, surah part). In `_shareVersesAsImage` and
      `_sharePartialAsImage`, the captured `RepaintBoundary` `Container` uses a flat dark-green
      gradient. Replace the single decoration with a layered Stack inside a `ClipRRect` (matching the
      rounded radius): (a) base green gradient `Container`; (b) `BackdropFilter(filter:
      ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8))` wrapping a semi-transparent `Container` (white
      `withValues(alpha: 0.05)`); (c) the existing content `Column`, now with a gold border drawn on a
      transparent top `Container`. The `BackdropFilter` blurs the green layer beneath it inside the
      `RepaintBoundary`, so the captured PNG shows a real frosted-glass green look. Keep all existing
      text/icons/share logic intact.
      Files: lib/features/quran/surah_reader_page.dart
      Verify: `flutter analyze` — no errors. Share a verse as image: preview + exported PNG show a
      frosted green glass background with the gold frame.

## FEAT-002 — Glassy design system + prayer/azkar surfaces  (tasks 7, 8)

- [ ] 5. Create reusable `GlassCard` in `lib/widgets/glass_card.dart`. A `StatelessWidget` wrapping
      `ClipRRect(borderRadius)` + `BackdropFilter(ImageFilter.blur)` + a `Container` with a
      semi-transparent fill, a subtle white border and optional gradient, taking params: `child`,
      `borderRadius` (default 20), `blurSigma` (default 12), `color`/`gradient`, `borderColor`,
      `borderWidth`, `padding`, `margin`, `isDark`. Use `AppColors` and `dart:ui` for the blur. No
      hardcoded hex when an `AppColors` constant fits.
      Files: lib/widgets/glass_card.dart
      Verify: `flutter analyze` — no errors.

- [ ] 6. Apply glass styling to the prayer-times card in `lib/widgets/prayer_times_card.dart`
      (task 7). Wrap the main card `Container` (the outer `GestureDetector` > `Container` with
      `cardBg`) with `GlassCard` (or an inline `ClipRRect`+`BackdropFilter`+translucent `Container`)
      so the card shows a frosted-glass fill with a subtle white border and blur; keep the gold
      highlight on the active/next prayer chip and all existing countdown-ring logic. Adjust the
      card's solid `cardBg` to a translucent value so the blur reads.
      Files: lib/widgets/prayer_times_card.dart
      Verify: `flutter analyze` — no errors. Dashboard prayer card shows frosted glass.

- [ ] 7. Replace the loading skeleton with blurred golden placeholder cards (task 8) in the same
      file's `_LoadingSkeleton`. Today it animates plain grey boxes. Change it to render soft blurred
      placeholder chips: wrap each placeholder `Container` in a `ClipRRect`+`BackdropFilter(
      ImageFilter.blur)` with an amber/gold tint for the FIRST slot (the next-prayer slot, wider 110)
      and a neutral glass tint for the rest, keeping the existing `AnimationController` opacity
      pulse. This matches the shared "blurred golden cards" screenshot.
      Files: lib/widgets/prayer_times_card.dart
      Verify: `flutter analyze` — no errors. With `_loadingPrayer` true (first launch) the card shows
      blurred golden/glass placeholders.

- [ ] 8. Glassy azkar-library header (task 7) in `lib/features/azkar/azkar_library_page.dart`. The
      page `AppBar` currently uses a solid `backgroundColor`. Set `backgroundColor: Colors.transparent`
      and `elevation: 0`, and add `flexibleSpace: ClipRect(child: BackdropFilter(filter:
      ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(decoration: BoxDecoration(gradient:
      LinearGradient(colors: [AppColors.darkGreen.withValues(alpha: 0.78), …midGreen alpha 0.6])))))`.
      Keep the existing `title`, `foregroundColor`, and the `bottom: TabBar`. (The AppBar already
      imports `dart:ui as ui`; reuse it for `ImageFilter`.)
      Files: lib/features/azkar/azkar_library_page.dart
      Verify: `flutter analyze` — no errors. Open مكتبة الأذكار: header is frosted glass, tabs work.

## FEAT-003 — Home screen restructure + behaviors  (tasks 1, 5, 10, 11, 4-header, 7-cards, 6, 12)
Depends on FEAT-002 (`GlassCard`). All `dashboard_page.dart` edits are in this FEAT to avoid conflicts.

- [ ] 9. Remove the "ذكر اليوم" section (task 1) in `lib/features/dashboard/dashboard_page.dart`.
      Delete the sliver block `if (_showAzkar) …[ _SectionTitle('ذكر اليوم'), _buildRotatingAzkar ] else
      _buildAzkarSettingsButton`. Remove `_showAzkar`, `_showAzkarPrefKey`, `_loadAzkarPref`,
      `_setShowAzkar`, and the now-unused `_buildRotatingAzkar` / `_buildAzkarSettingsButton` methods.
      Remove the `_loadAzkarPref()` call in `initState`. Grep `azkarCategories` and `Dhikr` afterwards —
      if the only uses were inside `_buildRotatingAzkar`, remove the now-unused import to avoid an
      analyzer warning. Do not touch the separate "مسبحة الذكر السريع" (`_HomeDhikrCounterCard`).
      Files: lib/features/dashboard/dashboard_page.dart
      Verify: `flutter analyze` — no errors. Home screen no longer shows "ذكر اليوم".

- [ ] 10. Glassy home header (task 4, header part) in the same file. The header `SliverToBoxAdapter`
      `Container` uses a solid green gradient with rounded bottom corners. Keep the green gradient as
      the base layer, but wrap the `Column` of header content in a `Stack`: green gradient `Container`
      + `BackdropFilter(ImageFilter.blur(sigma ~10))` over a translucent white
      `Container(color: Colors.white.withValues(alpha: 0.06))` + a subtle white `Border` + the
      existing content `Column`. Use `ClipRRect` with the existing bottom-left/right radius so the
      blur stays inside the rounded shape. Header stays green but reads as frosted premium glass.
      Files: lib/features/dashboard/dashboard_page.dart
      Verify: `flutter analyze` — no errors. Header looks frosted/glassy green.

- [ ] 11. Move "محاسبة اليوم" to a small floating button (task 5). Remove the sliver block
      `if (!isGuest) …[ _SectionTitle('محاسبة اليوم'), _buildDailyAccountability ]`. Remove the
      `_buildDailyAccountability` method and the now-unused `_SuccessCard` / `_AccountabilityCard`
      classes (grep to confirm no other references). Add a `floatingActionButton` to the `Scaffold`,
      shown only when `!isGuest`, wrapped in `Padding(EdgeInsets.only(bottom: 96))` so it clears the
      `MiniPlayer` + `_ModernNavBar`. Use `FloatingActionButton.extended` (small) with
      `Icons.check_circle_outline_rounded` + label `محاسبة اليوم` (`_f(sz: 13, fw: FontWeight.w700,
      c: Colors.white)`), `backgroundColor: AppColors.darkGreen`, `onPressed: () =>
      _showAccountabilityDialog(isDark)`. Keep `_showAccountabilityDialog`, `_saveQuickAccountability`,
      `_checkTodayAccountability`, `_CheckItem` and the five checkbox state fields (the dialog still
      works; it just opens from the FAB now). Optionally tint the FAB `AppColors.gold` when
      `_isAccountabilityDone` is true.
      Files: lib/features/dashboard/dashboard_page.dart
      Verify: `flutter analyze` — no errors. Logged-in user sees a small "محاسبة اليوم" FAB (bottom)
      that opens the accountability dialog; guests do not see it.

- [ ] 12. Glassy feature cards + quick chips (task 7, dashboard part) in the same file. Replace the
      `Container` decoration of `_FeatureCard` (currently `Material(color: …)` + `InkWell` + bordered
      `Container`) and of `_QuickChip`'s icon bubble with `GlassCard` (import from
      `lib/widgets/glass_card.dart`) — frosted translucent fill + subtle white border + blur, keeping
      the colored icon and label. Preserve `InkWell` tap ripple (put `GlassCard` behind the
      `Material`/`InkWell`, or use `GlassCard` as the `Material` child with an `InkWell` on top).
      Files: lib/features/dashboard/dashboard_page.dart
      Verify: `flutter analyze` — no errors. Feature grid + quick-access chips look frosted glass.

- [ ] 13. Add the Ramadan 2027 countdown widget (task 10). Create
      `lib/widgets/ramadan_countdown_widget.dart` — a `StatefulWidget` that computes days remaining
      to `DateTime(2027, 2, 8)` and renders a luxury card: dark-green/gold `LinearGradient`, a subtle
      Islamic-geometric pattern via stacked `Container` decorations / `CustomPaint`-free radial
      highlights, moon/star `Icons` (e.g. `Icons.nights_stay_rounded`, `Icons.star_rounded`) in gold,
      the tagline `انتظرونا مع مزايا مميزة في رمضان القادم`, the dua
      `اللهم بلغنا رمضان في عفو وعافية`, and a prominent days-remaining number (gold, bold). Add a
      share button: capture the card via a `RepaintBoundary` + `GlobalKey` → `boundary.toImage(
      pixelRatio: 3)` → write PNG to `getTemporaryDirectory()` → `Share.shareXFiles([XFile(path)],
      text: …)`. Use `AppColors` + `GoogleFonts.ibmPlexSansArabic`, RTL. Then in `dashboard_page.dart`
      add a `SliverToBoxAdapter` with `_SectionTitle('قريباً... رمضان 2027', icon:
      Icons.nights_stay_rounded)` + the widget, placed right after the `_buildLastReadQuranCard`
      sliver. Import the new widget.
      Files: lib/widgets/ramadan_countdown_widget.dart, lib/features/dashboard/dashboard_page.dart
      Verify: `flutter analyze` — no errors. Home shows the Ramadan countdown card; tapping share
      exports a PNG of the card.

- [ ] 14. Add "المساجد" to the bottom nav (task 11) in `_ModernNavBar` (same file). Insert a sixth
      `_NavButton(icon: Icons.mosque_rounded, label: 'المساجد', selected: currentIndex == 5, onTap: ()
      => NearbyMosquesPage.show(context))` — place it after "القبلة" and before the profile/login
      button. `NearbyMosquesPage` is already imported. The nav `Row` uses `spaceAround`; 6 buttons fit
      (labels only render when selected).
      Files: lib/features/dashboard/dashboard_page.dart
      Verify: `flutter analyze` — no errors. Bottom nav shows المساجد; tapping opens the mosques sheet.

- [ ] 15. Gate the morning/evening azkar reminder to fire only after the user reaches the dashboard
      (task 6). In `lib/services/azkar_reminder_service.dart` add `static bool _userEnteredApp =
      false;` and a public `void markUserEnteredApp() { _userEnteredApp = true; }`; add an early return
      `if (!_userEnteredApp) return;` at the top of `checkAndShowReminder`. In
      `dashboard_page.dart initState`, after `super.initState();` add
      `AzkarReminderService().markUserEnteredApp();` and a post-frame
      `WidgetsBinding.instance.addPostFrameCallback((_) =>
      AzkarReminderService().checkAndShowReminder());`. In `lib/main.dart` `_BasairAppState.initState`
      REMOVE the `WidgetsBinding.instance.addPostFrameCallback(… Future.delayed(2500) …
      checkAndShowReminder())` block (the dashboard now triggers it). Keep the resume trigger in
      `didChangeAppLifecycleState` — it is now gated by the flag. (There is no `isGuest` flag on
      `AppAuthProvider`; "signed in as a guest" = non-authenticated user who pressed "تخطي - الدخول
      كضيف" on the login page and reached the dashboard — both guests and users pass through
      `DashboardPage.initState`, so the flag covers both.)
      Files: lib/services/azkar_reminder_service.dart, lib/features/dashboard/dashboard_page.dart,
            lib/main.dart
      Verify: `flutter analyze` — no errors. Reminder does NOT appear on splash/onboarding; it appears
      only once the dashboard is shown (guest or user), within the morning/evening time windows.

- [ ] 16. Fix English worship keys leaking into the UI (task 12). In `dashboard_page.dart`
      `_getWorshipDisplayName` (near the bottom of the file) add the missing cases so raw keys map to
      Arabic: `case 'fajr_prayed': return 'صلاة الفجر';`, `case 'fajr_woke_alarm': return
      'الاستيقاظ لصلاة الفجر';`, `case 'evening_azkar_done': return 'أذكار المساء';`, and
      `case 'quran_read':` already maps — verify; add `case 'azkar_done': return 'الأذكار';` (already
      present) and `case 'istighfar_done': return 'الاستغفار';` (already present). Then mirror the
      same mapping in `lib/services/daily_summary_service.dart` `_getWorshipDisplayName` which is
      currently missing `fajr_prayed`, `fajr_woke_alarm`, `quran_read`, `azkar_done`,
      `evening_azkar_done`, `istighfar_done` — add all of them so the daily-summary text also shows
      Arabic. (The leak happens because `getTodaySummary` returns `completedWorships` as raw
      `entry.key` strings, rendered under "العبادات الأخرى:" via this helper; `fajr_prayed` /
      `fajr_woke_alarm` currently hit `default: return key`.)
      Files: lib/features/dashboard/dashboard_page.dart, lib/services/daily_summary_service.dart
      Verify: `flutter analyze` — no errors. A day with fajr prayed / woke-alarm logged shows "صلاة
      الفجر" / "الاستيقاظ لصلاة الفجر" under "العبادات الأخرى", never the English keys.

---

## Final verification (whole task)

- [ ] 17. Run `flutter analyze` from `e:/NiyyahTracker-mobile-app-ai` and confirm it reports **no
      errors** (warnings on truly unused imports should be cleaned up). This is the contract for
      "the revamp is done". Do not run/fix `flutter test` — its single boilerplate test is
      pre-existing broken and out of scope.
      Verify: `flutter analyze` exits clean (0 errors).
