class CreateFeedSourcesAndImportTracking < ActiveRecord::Migration[7.0]
  def change
    create_table :feed_sources do |t|
      t.bigint :user_id, null: false
      t.string :url, null: false
      t.boolean :enabled, null: false, default: true
      t.boolean :feed_mark_canonical, null: false, default: false
      t.boolean :feed_referential_link, null: false, default: true
      t.bigint :fallback_author_id
      t.bigint :fallback_organization_id
      t.datetime :last_fetched_at
      t.datetime :last_imported_at
      t.text :last_error_message

      t.timestamps
    end

    add_foreign_key :feed_sources, :users
    add_foreign_key :feed_sources, :users, column: :fallback_author_id
    add_foreign_key :feed_sources, :organizations, column: :fallback_organization_id

    create_table :feed_import_runs do |t|
      t.bigint :user_id, null: false
      t.bigint :feed_source_id, null: false
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :detected_items_count, null: false, default: 0
      t.integer :imported_items_count, null: false, default: 0
      t.integer :skipped_items_count, null: false, default: 0
      t.integer :failed_items_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_foreign_key :feed_import_runs, :users
    add_foreign_key :feed_import_runs, :feed_sources

    create_table :feed_import_items do |t|
      t.bigint :user_id, null: false
      t.bigint :feed_source_id, null: false
      t.bigint :feed_import_run_id, null: false
      t.bigint :article_id
      t.string :external_id
      t.string :source_url
      t.string :title
      t.integer :status, null: false, default: 0
      t.string :skip_reason
      t.text :error_message
      t.datetime :published_at

      t.timestamps
    end

    add_foreign_key :feed_import_items, :users
    add_foreign_key :feed_import_items, :feed_sources
    add_foreign_key :feed_import_items, :feed_import_runs
    add_foreign_key :feed_import_items, :articles
  end
end
