FactoryBot.define do
  factory :rss_feed_item do
    rss_feed
    item_url { "https://example.com/article" }
  end
end
