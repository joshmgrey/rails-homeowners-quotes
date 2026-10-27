FactoryBot.define do
  factory :quote do
    state { "FL" }
    street_address { "123 Ocean Dr" }
    zip { "33139" }
    year_built { 1995 }
    roof_age_years { 8 }
    dwelling_coverage_cents { 300_000_00 }

    # expires_at is set by a before_create callback, so overwrite it afterwards.
    trait :expired do
      after(:create) { |quote| quote.update_column(:expires_at, 1.minute.ago) }
    end
  end
end
