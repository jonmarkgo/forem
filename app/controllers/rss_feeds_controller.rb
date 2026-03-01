class RssFeedsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_rss_feed, only: %i[show edit update destroy]

  def index
    @rss_feeds = current_user.rss_feeds.order(created_at: :desc)
  end

  def show; end

  def new
    @rss_feed = current_user.rss_feeds.new
  end

  def edit; end

  def create
    @rss_feed = current_user.rss_feeds.new(rss_feed_params)

    if @rss_feed.save
      redirect_to rss_feeds_url, notice: "RSS feed was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @rss_feed.update(rss_feed_params)
      redirect_to rss_feeds_url, notice: "RSS feed was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rss_feed.destroy
    redirect_to rss_feeds_url, notice: "RSS feed was successfully destroyed."
  end

  private

  def set_rss_feed
    @rss_feed = current_user.rss_feeds.find(params[:id])
  end

  def rss_feed_params
    params.require(:rss_feed).permit(:url, :organization_id, :author_id)
  end
end
