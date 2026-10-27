# Rails Homeowners Quotes

[![CI](https://github.com/joshmgrey/rails-homeowners-quotes/actions/workflows/ci.yml/badge.svg)](https://github.com/joshmgrey/rails-homeowners-quotes/actions/workflows/ci.yml)

A small homeowners insurance API in Ruby on Rails: price a quote, then bind it into a policy.
Built to learn Rails conventions with a domain that has real correctness rules
(one policy per quote, quotes expire, binding is safe to retry).

**Stack:** Ruby 3.3 · Rails 8.0 (API mode) · PostgreSQL 16 · RSpec + FactoryBot · Docker Compose

## Run it

Everything runs in Docker, so you don't need Ruby or Postgres installed locally.

```bash
docker compose up -d db
docker compose run --rm web bundle install
docker compose run --rm web bin/rails db:create db:migrate
docker compose run --rm web bundle exec rspec
docker compose up web
```

The API is then at http://localhost:3000. For a Rails console:

```bash
docker compose run --rm web bin/rails console
```

## API

| Method | Path | Notes |
|---|---|---|
| `POST` | `/quotes` | Prices a quote. `201`, or `422` with `errors` |
| `GET` | `/quotes/:id` | |
| `POST` | `/quotes/:id/bind` | Needs an `Idempotency-Key` header. `201` new policy, `200` same key retried, `409` already bound, `422` expired |
| `GET` | `/policies` | Every policy with its quote's address. Eager-loads quotes to avoid N+1 queries |
| `GET` | `/policies/:id` | |

```bash
curl -X POST localhost:3000/quotes -H "Content-Type: application/json" \
  -d '{"quote":{"state":"FL","street_address":"123 Ocean Dr","zip":"33139","year_built":1995,"roof_age_years":8,"dwelling_coverage_cents":30000000}}'

curl -X POST localhost:3000/quotes/1/bind -H "Idempotency-Key: abc-123"
```

Money is stored as integer cents (`premium_cents`), never floats.

## Business rules

- We write in FL, TX, LA, AL and SC. Coverage must be $100K to $2M.
- Premium = coverage (per $1,000) × state base rate × roof-age factor × home-age factor, with a $500 minimum. See `PremiumCalculator`.
- A quote is valid for 30 days.
- A quote can become at most one policy. This is enforced three ways: a row lock while binding, a model validation, and a unique index in Postgres.
- Retrying a bind with the same `Idempotency-Key` returns the original policy instead of failing.

## Where each Rails concept lives

| Concept | File | Equivalent you already know |
|---|---|---|
| Migrations, indexes, check constraints | `db/migrate/` | Prisma migrate |
| ActiveRecord model, validations, `enum` | `app/models/quote.rb` | Prisma model + Zod |
| Associations (`has_one` / `belongs_to`) | `app/models/quote.rb`, `app/models/policy.rb` | Prisma relations, JPA `@OneToOne` |
| Callbacks (`before_create`) | `app/models/quote.rb` | Prisma middleware, JPA `@PrePersist` |
| Plain Ruby service objects | `app/services/` | NestJS providers |
| Row locking (`with_lock`) + transaction | `app/services/quote_binder.rb` | `SELECT ... FOR UPDATE` in a Prisma `$transaction` |
| Strong params (`params.expect`) | `app/controllers/quotes_controller.rb` | NestJS DTO + ValidationPipe |
| `rescue_from` error mapping | `app/controllers/application_controller.rb` | NestJS exception filters |
| RESTful routes, member routes | `config/routes.rb` | NestJS `@Controller` / `@Post(':id/bind')` |
| Model, service and request specs | `spec/` | Jest unit + Supertest |
| Factories | `spec/factories/quotes.rb` | Test fixtures / builders |
| Concurrency test | `spec/services/quote_binder_spec.rb` | Stone Harbor signup race test |

## Practice exercises

Do these yourself. Each one is a common Rails interview topic.

1. **N+1 queries.** Add `GET /policies` that lists policies with their quote's address. Watch the log for one query per policy, then fix it with `includes(:quote)`.
2. **Scopes.** Add `Quote.active` (pending and not expired) and a spec for it.
3. **Background job.** Add an ActiveJob that marks pending quotes past `expires_at` as `expired`. You'll need a new enum value and a migration to update the check constraint.
4. **Cancellation.** Add `POST /policies/:id/cancel` that refunds the unused premium pro rata. Put the math in a service and test the edge days.
5. **Validation vs. constraint.** Delete the unique index on `policies.quote_id` and the `with_lock` call, then run the concurrency spec. See why the model validation alone isn't enough.
6. **Pagination and filtering.** `GET /quotes?state=FL&page=2` with a spec for each.
