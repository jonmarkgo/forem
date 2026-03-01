class RssFeedItem < ApplicationRecord
  belongs_to :rss_feed
  belongs_to :article, optional: true

  validates :item_url, presence: true, uniqueness: { scope: :rss_feed_id }

  enum status: {
    processing: "processing",
    success: "success",
    error: "error"
  }
end
