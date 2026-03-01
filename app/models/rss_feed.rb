class RssFeed < ApplicationRecord
  belongs_to :user
  belongs_to :organization, optional: true
  belongs_to :author, class_name: "User", optional: true
  has_many :rss_feed_items, dependent: :destroy

  validates :url, presence: true, uniqueness: { scope: :user_id }

  enum status: {
    active: "active",
    processing: "processing",
    success: "success",
    error: "error",
    disabled: "disabled"
  }

  def processing!
    update!(status: :processing, processing_started_at: Time.current)
  end

  def success!
    update!(status: :success, processing_finished_at: Time.current)
  end

  def error!(error_message)
    update!(status: :error, processing_finished_at: Time.current, error_message: error_message)
  end

  def disable!
    update!(status: :disabled)
  end
end
