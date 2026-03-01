class AddFeedImportTrackingIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :feed_sources, :user_id, algorithm: :concurrently
    add_index :feed_sources, %i[user_id enabled], algorithm: :concurrently
    add_index :feed_sources, %i[user_id url], unique: true, algorithm: :concurrently

    add_index :feed_import_runs, :feed_source_id, algorithm: :concurrently
    add_index :feed_import_runs, %i[user_id created_at], algorithm: :concurrently
    add_index :feed_import_runs, %i[feed_source_id created_at], algorithm: :concurrently
    add_index :feed_import_runs, %i[feed_source_id status created_at], algorithm: :concurrently, name: "idx_feed_import_runs_source_status_created_at"

    add_index :feed_import_items, :feed_import_run_id, algorithm: :concurrently
    add_index :feed_import_items, %i[feed_source_id created_at], algorithm: :concurrently
    add_index :feed_import_items, %i[feed_source_id status], algorithm: :concurrently
    add_index :feed_import_items, %i[feed_import_run_id status], algorithm: :concurrently
    add_index :feed_import_items, %i[user_id source_url], algorithm: :concurrently
  end
end
