require "rails_helper"

RSpec.describe Feeds::ImportFromRssFeed do
  let(:user) { create(:user) }
  let(:rss_feed) { create(:rss_feed, user: user) }
  let(:feed_xml) { file_fixture("feeds/sample.xml").read }
  let(:feed_url) { "https://example.com/feed" }

  before do
    allow(HTTParty).to receive(:get).and_return(double(body: feed_xml))
  end

  it "imports articles from an RSS feed" do
    expect {
      described_class.call(rss_feed)
    }.to change(Article, :count).by(2)
  end

  it "updates the rss_feed status to success" do
    described_class.call(rss_feed)
    expect(rss_feed.reload.status).to eq("success")
  end

  it "creates rss_feed_items for each item in the feed" do
    expect {
      described_class.call(rss_feed)
    }.to change(RssFeedItem, :count).by(2)
  end

  it "does not import already imported items" do
    create(:rss_feed_item, rss_feed: rss_feed, item_url: "https://example.com/article1")
    expect {
      described_class.call(rss_feed)
    }.to change(Article, :count).by(1)
  end

  context "when the feed is unreachable" do
    before do
      allow(HTTParty).to receive(:get).and_raise(StandardError)
    end

    it "updates the rss_feed status to error" do
      described_class.call(rss_feed)
      expect(rss_feed.reload.status).to eq("error")
    end
  end
end
