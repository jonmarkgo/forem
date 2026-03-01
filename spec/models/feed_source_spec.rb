require "rails_helper"

RSpec.describe FeedSource do
  before do
    allow(Feeds::ValidateUrl).to receive(:call).and_return(true)
  end

  describe "validations" do
    subject(:feed_source) { build(:feed_source) }

    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(500) }
    it { is_expected.to validate_inclusion_of(:feed_mark_canonical).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:feed_referential_link).in_array([true, false]) }
  end

  describe "#effective_fallback_author" do
    it "falls back to user when fallback author is not set" do
      feed_source = create(:feed_source, fallback_author: nil)

      expect(feed_source.effective_fallback_author).to eq(feed_source.user)
    end
  end

  describe "fallback organization validation" do
    it "rejects organization if user is not org admin", vcr: { cassette_name: "feeds_import_medium_vaidehi" } do
      user = create(:user)
      organization = create(:organization)

      feed_source = build(:feed_source, user: user, fallback_organization: organization, url: "https://medium.com/feed/@vaidehijoshi")

      expect(feed_source).not_to be_valid
      expect(feed_source.errors[:fallback_organization_id]).to be_present
    end
  end
end
