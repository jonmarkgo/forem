FactoryBot.define do
  factory :feed_source do
    user
    url { "https://medium.com/feed/@vaidehijoshi" }
    enabled { true }
    feed_mark_canonical { false }
    feed_referential_link { true }
    fallback_author { user }
    fallback_organization { nil }
  end
end
