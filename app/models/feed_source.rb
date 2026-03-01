class FeedSource < ApplicationRecord
  belongs_to :user
  belongs_to :fallback_author, class_name: "User", optional: true
  belongs_to :fallback_organization, class_name: "Organization", optional: true

  has_many :feed_import_runs, dependent: :delete_all
  has_many :feed_import_items, dependent: :delete_all

  scope :enabled, -> { where(enabled: true) }

  validates :url, presence: true, length: { maximum: 500 }, url: { schemes: %w[https http] }
  validates :feed_mark_canonical, inclusion: { in: [true, false] }
  validates :feed_referential_link, inclusion: { in: [true, false] }
  validate :validate_feed_url, if: :will_save_change_to_url?
  validate :validate_fallback_author
  validate :validate_fallback_organization_admin_rights

  def effective_fallback_author
    fallback_author || user
  end

  private

  def validate_feed_url
    return if url.blank?

    valid = Feeds::ValidateUrl.call(url)
    errors.add(:url, I18n.t("models.users.setting.invalid_rss")) unless valid
  rescue StandardError => e
    errors.add(:url, e.message)
  end

  def validate_fallback_organization_admin_rights
    return if fallback_organization_id.blank?
    return if user&.org_admin?(fallback_organization)

    errors.add(:fallback_organization_id, :invalid)
  end

  def validate_fallback_author
    return if fallback_author_id.blank?
    return if fallback_author_id == user_id

    errors.add(:fallback_author_id, :invalid)
  end
end
