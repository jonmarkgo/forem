FactoryBot.define do
  factory :feed_import_run do
    user
    feed_source
    status { :queued }
    started_at { Time.current }
    finished_at { nil }
    detected_items_count { 0 }
    imported_items_count { 0 }
    skipped_items_count { 0 }
    failed_items_count { 0 }
  end
end
