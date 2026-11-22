# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rails 8.1 API-only backend for a restaurant application (no views — JSON only). PostgreSQL, Ruby 4.0.6. The full intended architecture (auth, real-time, background jobs, serialization) is described in `backend_implementation_plan.md` — consult it for design intent before implementing a new area, since much of it is not yet built.

Current state: models, migrations, and validations for the six core resources exist, but there are **no controllers or routes yet** beyond the default health check (`config/routes.rb`), and the database has not been created/migrated (no `db/schema.rb`). `rack-cors` and `jwt` are referenced in the plan but not yet added to the Gemfile.

## Commands

```bash
bin/setup                 # install deps, prepare db (per bin/setup)
bin/rails db:create db:migrate

bin/rails test             # run full test suite
bin/rails test test/models/order_test.rb          # single file
bin/rails test test/models/order_test.rb:12       # single test at line

bin/rubocop                # lint (rubocop-rails-omakase house style)
bin/brakeman                # static security analysis
bin/bundler-audit           # gem vulnerability audit

bin/rails server            # run the app
bin/rails console
```

There is no `db/schema.rb` checked in yet — run `bin/rails db:create db:migrate` before running tests or the server for the first time.

## Architecture

**Domain model** (see `app/models/`): `User` (role enum: customer/waiter/chef/admin, `has_secure_password`) → has many `Order`s. `Order` (status enum: pending/preparing/ready/delivered/cancelled) belongs to a `User` and optionally a `RestaurantTable`, and has many `OrderItem`s (through which it reaches `MenuItem`s). `MenuItem` belongs to a `Category` and has many `OrderItem`s. `OrderItem` snapshots `unit_price` at order time so later menu price changes don't rewrite order history.

**Planned but not yet implemented** (see `backend_implementation_plan.md` for details):
- **Auth**: JWT-based (`has_secure_password` + `jwt` gem), not session/cookie based since this is API-only. Role checks gate write access to state transitions (e.g. only `chef` can move an order to `preparing`).
- **Real-time**: ActionCable `KitchenOrdersChannel` broadcasting order updates to the kitchen display, triggered via an `after_update_commit` callback on `Order` when status changes.
- **Background jobs**: Solid Queue (already in the Gemfile) for order confirmation emails, payment processing, and cleanup of abandoned pending orders.
- **Serialization**: `blueprinter` or `active_model_serializers` to shape JSON responses and keep sensitive fields (e.g. `password_digest`) out of API output.

When adding controllers/routes, follow the API-only conventions already set: `ApplicationController < ActionController::API`, `config.api_only = true` in `config/application.rb`.
