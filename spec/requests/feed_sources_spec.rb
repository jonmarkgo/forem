require "rails_helper"

RSpec.describe "FeedSources" do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /dashboard/rss-import" do
    it "renders dashboard" do
      get dashboard_rss_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("RSS Import")
    end
  end

  describe "POST /dashboard/rss-import/feeds" do
    it "creates a feed source", vcr: { cassette_name: "feeds_import_medium_vaidehi" } do
      expect do
        post dashboard_feed_sources_path, params: {
          feed_source: {
            url: "https://medium.com/feed/@vaidehijoshi",
            feed_mark_canonical: true,
            feed_referential_link: true,
            fallback_author_id: user.id,
          },
        }
      end.to change(user.feed_sources, :count).by(1)
    end
  end

  describe "PATCH /dashboard/rss-import/feeds/:id" do
    it "updates a feed source", vcr: { cassette_name: "feeds_import_medium_vaidehi" } do
      feed_source = create(:feed_source, user: user, url: "https://medium.com/feed/@vaidehijoshi")

      patch dashboard_feed_source_path(feed_source), params: {
        feed_source: {
          enabled: false,
        },
      }

      expect(feed_source.reload.enabled).to be(false)
    end
  end

  describe "DELETE /dashboard/rss-import/feeds/:id" do
    it "deletes a feed source" do
      feed_source = create(:feed_source, user: user)

      expect do
        delete dashboard_feed_source_path(feed_source)
      end.to change(user.feed_sources, :count).by(-1)
    end
  end

  describe "POST /dashboard/rss-import/feeds/:id/fetch" do
    it "enqueues a fetch job" do
      feed_source = create(:feed_source, user: user)
      allow(Feeds::ImportArticlesWorker).to receive(:perform_async)

      post fetch_dashboard_feed_source_path(feed_source)

      expect(Feeds::ImportArticlesWorker).to have_received(:perform_async).with([], nil, [feed_source.id])
    end
  end
end
