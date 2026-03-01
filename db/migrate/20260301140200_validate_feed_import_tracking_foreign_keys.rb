class ValidateFeedImportTrackingForeignKeys < ActiveRecord::Migration[7.0]
  def change
    validate_foreign_key :feed_sources, :users
    validate_foreign_key :feed_sources, :users, column: :fallback_author_id
    validate_foreign_key :feed_sources, :organizations, column: :fallback_organization_id

    validate_foreign_key :feed_import_runs, :users
    validate_foreign_key :feed_import_runs, :feed_sources

    validate_foreign_key :feed_import_items, :users
    validate_foreign_key :feed_import_items, :feed_sources
    validate_foreign_key :feed_import_items, :feed_import_runs
    validate_foreign_key :feed_import_items, :articles
  end
end
