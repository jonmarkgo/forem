FactoryBot.define do
  factory :feed_import_item do
    user
    feed_source
    feed_import_run
    status { :imported }
    source_url { "https://example.com/my-post" }
    title { "Imported post title" }
  end
end
