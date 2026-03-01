require "rails_helper"

RSpec.describe RssFeedsController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      rss_feed = create(:rss_feed, user: user)
      get :show, params: { id: rss_feed.to_param }
      expect(response).to be_successful
    end
  end

  describe "GET #new" do
    it "returns a success response" do
      get :new
      expect(response).to be_successful
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      rss_feed = create(:rss_feed, user: user)
      get :edit, params: { id: rss_feed.to_param }
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new RssFeed" do
        expect {
          post :create, params: { rss_feed: attributes_for(:rss_feed) }
        }.to change(RssFeed, :count).by(1)
      end

      it "redirects to the rss_feeds list" do
        post :create, params: { rss_feed: attributes_for(:rss_feed) }
        expect(response).to redirect_to(rss_feeds_url)
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e. to display the 'new' template)" do
        post :create, params: { rss_feed: attributes_for(:rss_feed, url: nil) }
        expect(response).to be_successful
      end
    end
  end

  describe "PUT #update" do
    let(:rss_feed) { create(:rss_feed, user: user) }

    context "with valid params" do
      let(:new_attributes) {
        { url: "https://new.url/feed.xml" }
      }

      it "updates the requested rss_feed" do
        put :update, params: { id: rss_feed.to_param, rss_feed: new_attributes }
        rss_feed.reload
        expect(rss_feed.url).to eq("https://new.url/feed.xml")
      end

      it "redirects to the rss_feeds list" do
        put :update, params: { id: rss_feed.to_param, rss_feed: attributes_for(:rss_feed) }
        expect(response).to redirect_to(rss_feeds_url)
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e. to display the 'edit' template)" do
        put :update, params: { id: rss_feed.to_param, rss_feed: attributes_for(:rss_feed, url: nil) }
        expect(response).to be_successful
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested rss_feed" do
      rss_feed = create(:rss_feed, user: user)
      expect {
        delete :destroy, params: { id: rss_feed.to_param }
      }.to change(RssFeed, :count).by(-1)
    end

    it "redirects to the rss_feeds list" do
      rss_feed = create(:rss_feed, user: user)
      delete :destroy, params: { id: rss_feed.to_param }
      expect(response).to redirect_to(rss_feeds_url)
    end
  end
end
