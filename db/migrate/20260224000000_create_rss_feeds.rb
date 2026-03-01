class CreateRssFeeds < ActiveRecord::Migration[7.0]
  def change
    create_table :rss_feeds do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :status, default: "active", null: false
      t.datetime :last_fetched_at
      t.datetime :processing_started_at
      t.datetime :processing_finished_at
      t.text :error_message
      t.references :organization, null: true, foreign_key: true
      t.references :author, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :rss_feed_items do |t|
      t.references :rss_feed, null: false, foreign_key: true
      t.string :item_url, null: false
      t.string :status, default: "processing", null: false
      t.references :article, null: true, foreign_key: true
      t.text :error_message
      t.timestamps
    end
  end
end
