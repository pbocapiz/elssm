# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LEAP ("Leave Enquiry and Access Portal") — a Flutter app (multi-platform: Android/iOS/web/Windows/macOS/Linux dirs all present) for an office leave/payroll management system (ESSLMS), backed by Supabase (Postgres + Auth). There is no custom backend server — the Flutter client talks to Supabase directly via `supabase_flutter`, and all authorization is enforced by Postgres Row Level Security (RLS) policies, not by client code.

## Commands

```
flutter pub get                                              # install dependencies
flutter analyze                                               # static analysis (run after any lib/ edit)
flutter analyze lib/some_file.dart                            # analyze a single file
flutter test                                                  # run all tests
flutter test test/widget_test.dart                            # run a single test file
flutter run --dart-define-from-file=dart_define.local.json    # run the app (pick a device/platform when prompted)
```

There's only one test file (`test/widget_test.dart`) and it's the default counter-app placeholder — it does not exercise this app's actual screens.

`flutter run` alone will boot into a "Missing Supabase configuration" screen — `SupabaseConfig.url`/`publishableKey` are read via `String.fromEnvironment` with no hardcoded fallback (see below), so they must come from `--dart-define-from-file`. `dart_define.local.json` is gitignored and holds the real values locally; `dart_define.example.json` (tracked) documents the expected keys (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`) for anyone setting up the repo fresh.

## Architecture

### Client structure

- `lib/main.dart` — initializes `Supabase.instance` with `SupabaseConfig.url`/`publishableKey` (`lib/supabase_config.dart`), then boots into `AuthGate`. Shows a "Missing Supabase configuration" screen instead if `SupabaseConfig.isConfigured` is false.
- `lib/auth_gate.dart` — stateful; a `StreamBuilder` on `Supabase.instance.client.auth.onAuthStateChange` shows `LoginPage` or `HomePage` reactively (no manual navigation on sign-out — `AuthGate` swaps itself automatically), and it also owns the password-reset landing flow: this app has no URL-path router, so instead of a distinct `/update-password` route, `AuthGate` watches for the `PASSWORD_RECOVERY` auth event (fired by `supabase_flutter` once it detects a recovery session in the redirect URL on web) and swaps in `UpdatePasswordPage` in place of Login/Home. An expired/already-used reset link never creates a session, so it never fires that event — that case is instead detected once at startup from the `error`/`error_code` query params Supabase appends to the redirect URL (`ResetLinkExpiredPage`). `ForgotPasswordPage` (reachable from a link on `LoginPage`, `Navigator.push` like `SignUpPage`) always shows the same result on request whether or not the account exists, per Supabase's own no-enumeration behavior — real send failures (bad SMTP config, rate limits) are still surfaced via a snackbar, since Supabase's API never distinguishes those from "account doesn't exist" either.
- `lib/home_page.dart` — the shell after login: builds `AppSidebar`, tracks the selected `SidebarItem`, and `_ContentArea` switches between the feature pages. Persists the last-selected sidebar item **per user id** in `SharedPreferences` (`elssm_last_page_<userId>`) so a shared browser doesn't leak one user's last page to the next signed-in user.
- `lib/widgets/app_sidebar.dart` — defines `SidebarItem` and `sidebarItemsForAccessLevel(accessLevel)`, which is the single source of truth for which nav items each role sees. `manageStartingCredits`, `leaveRecords`, `leaveCreditReport`, `reports` are grouped under a collapsible "Leave Credits" section (`leaveCreditsGroupItems`).
- `lib/models/*.dart` — plain immutable data classes with a `fromMap(Map<String, dynamic>)` factory that parses Supabase row/RPC responses. No JSON codegen, no `freezed`.
- `lib/services/*.dart` — one static-method class per feature (e.g. `MemberService`, `TransactionService`, `LeaveCreditReportService`), each wrapping `Supabase.instance.client.from(...)`/`.rpc(...)` calls. Services are thin: they do not re-implement authorization — comments in the services routinely point at *which* RLS policy/migration enforces what the query returns.

### Access levels

Every page/query is scoped by an integer `accessLevel` carried on the signed-in user: **1 = Admin, 2 = Approver, 3 = Employee** (least-privileged default). This convention is threaded through `Employee.accessLevel`, `MembersPage(accessLevel: ...)`, `PayrollPage(canEdit: accessLevel <= 2)`, `sidebarItemsForAccessLevel`, etc. When adding a feature that differs by role, follow this existing `accessLevel <= 2` (Admin+Approver) / `accessLevel == 3` (Employee-only) pattern rather than inventing new role checks — and remember the *real* boundary must live in an RLS policy, since a client-side check is only a UI convenience.

### Supabase/Postgres (`supabase/sql/`)

This directory is **gitignored** (not tracked in the repo) but present on disk — treat it as the source of truth for schema/RLS when reasoning about what a query is allowed to return, and check it before assuming a client-side filter is the actual security boundary.

- Numbered, sequential, hand-run migrations: `001_users_table_and_confirm_trigger.sql`, `002_esslms_business_schema.sql`, ... `029_skip_zero_value_monthly_accrual.sql`. Each file's header comment says what to run it after. New schema changes should follow this same pattern: a new numbered file, run manually in the Supabase SQL editor (there is no migration-runner tooling in this repo).
- Core tables: `public.users`, `public.gl_offices`, `public.els_employees`, `public.els_leave_types`, `public.els_leave_credits`, `public.els_leave_deductions`, `public.els_leave_opening_balance`, `public.els_leave_applications`, `public.els_payroll`, `public.pending_users`.
- All of the above have `ENABLE ROW LEVEL SECURITY` plus policies (see `002_esslms_business_schema.sql` §4, and later files like `023_approver_admin_edit_members.sql`, `026_approver_admin_edit_employee_details.sql`) scoping rows by accesslevel and office. Client `select`/`update`/`insert` calls rely entirely on these policies — the Dart code does not add its own row filtering for authorization (it does sometimes add *display* filters, e.g. dropdown "Filter by X" UI, which is different from an authorization boundary).
- Read-heavy screens query views (`public.v_user_profiles`, `public.v_leave_balances`, `public.v_leave_transactions`) or RPCs (`leave_credit_report`, `current_employee_id`) rather than raw tables, so joins/aggregation live in Postgres, not Dart.
- The Supabase anon/publishable key is safe to have client-side by design (it identifies the `anon` Postgres role; RLS is what actually restricts it) — it's kept out of tracked source anyway per project preference. `supabase_config.dart`'s `url`/`publishableKey` are `String.fromEnvironment` reads with no hardcoded fallback, supplied via `--dart-define-from-file=dart_define.local.json` locally (gitignored) and via `--dart-define` from GitHub Actions repo secrets in `.github/workflows/deploy-gh-pages.yml` for the GitHub Pages deploy. Never add the `service_role` key to client code.

### UI conventions

- `lib/theme.dart` defines the app's palette (`navyBlue`, `taupe`, etc.) and `buildAppTheme()` — reuse these constants instead of hardcoding colors.
- Filter/report screens (`leave_credit_report_page.dart`, `leave_report_export_page.dart`, `leave_records_page.dart`) follow a recurring layout: a `FutureBuilder` fetches rows once, filter dropdowns (User/Leave Type/Year/Access Level) derive their option lists from the fetched rows themselves (not a separate query) and filter client-side, and results render in a `DataTable` wrapped in nested `SingleChildScrollView`s (vertical outer, horizontal inner via `LayoutBuilder` + `ConstrainedBox(minWidth: constraints.maxWidth)`) so wide tables scroll instead of overflowing.
- Export screens (`leave_report_export_page.dart`) build `.xlsx` files with the `excel` package and save them via `file_saver`; numeric leave-balance columns are styled with a `"0.000"` custom number format to keep 3-decimal-place consistency with the rest of the app's day-count display.
