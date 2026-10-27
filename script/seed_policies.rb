# Creates a handful of bound policies for trying GET /policies locally.
#   docker compose run --rm web bin/rails runner script/seed_policies.rb
addresses = [
  [ "FL", "123 Ocean Dr", "33139" ],
  [ "TX", "9 Elm St", "78701" ],
  [ "LA", "400 Bourbon St", "70130" ],
  [ "AL", "12 Magnolia Ave", "36602" ],
  [ "SC", "88 King St", "29401" ]
]

addresses.each do |state, street_address, zip|
  quote = Quote.create!(
    state: state,
    street_address: street_address,
    zip: zip,
    year_built: 1990,
    roof_age_years: 10,
    dwelling_coverage_cents: 350_000_00
  )
  QuoteBinder.call(quote: quote, idempotency_key: SecureRandom.uuid)
end

puts "#{Policy.count} policies"
