class FeedImportRun < ApplicationRecord
  belongs_to :user
  belongs_to :feed_source

  has_many :feed_import_items, dependent: :delete_all

  enum status: {
    queued: 0,
    processing: 1,
    succeeded: 2,
    failed: 3,
    partially_succeeded: 4,
  }

  validates :status, presence: true
end
