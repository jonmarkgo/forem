FactoryBot.define do
  factory :rss_feed do
    user
    url { "https://example.com/feed" }
  end
end
