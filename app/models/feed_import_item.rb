class FeedImportItem < ApplicationRecord
  belongs_to :user
  belongs_to :feed_source
  belongs_to :feed_import_run
  belongs_to :article, optional: true

  enum status: {
    imported: 0,
    skipped: 1,
    failed: 2,
  }

  validates :status, presence: true
end
