module Feeds
  class ImportFromRssFeed
    def self.call(rss_feed)
      new(rss_feed).call
    end

    def initialize(rss_feed)
      @rss_feed = rss_feed
      @user = rss_feed.user
    end

    def call
      return unless @user

      @rss_feed.processing!

      feed_xml = fetch_feed
      return if feed_xml.blank?

      feedjira_object = parse_feed(feed_xml)
      return if feedjira_object.blank?

      articles = create_articles_from_feed(feedjira_object)

      @rss_feed.success!

      articles
    rescue StandardError => e
      @rss_feed.error!(e.message)
      report_error(e)
    end

    private

    def fetch_feed
      response = HTTParty.get(@rss_feed.url.strip, timeout: 10, headers: { "User-Agent" => "Forem Feeds Importer" })
      response.body
    end

    def parse_feed(feed_xml)
      Feedjira.parse(feed_xml)
    end

    def create_articles_from_feed(feed)
      articles = []

      feed.entries.reverse_each do |item|
        next if Feeds::CheckItemMediumReply.call(item) || item_previously_imported?(item)

        feed_source_url = item.url.strip.split("?source=")[0]
        
        rss_feed_item = @rss_feed.rss_feed_items.create!(item_url: feed_source_url)

        begin
          article = Article.create!(
            feed_source_url: feed_source_url,
            user_id: @user.id,
            organization_id: @rss_feed.organization_id,
            author_id: @rss_feed.author_id,
            published_from_feed: true,
            show_comments: true,
            body_markdown: Feeds::AssembleArticleMarkdown.call(item, @user, feed, feed_source_url),
          )
          subscribe_author_to_comments(@user, article)
          articles.append(article)
          rss_feed_item.update!(status: "success", article_id: article.id)
        rescue StandardError => e
          rss_feed_item.update!(status: "error", error_message: e.message)
          report_error(e, item: item)
          next
        end
      end

      if articles.length.positive?
        Slack::WorkflowWebhookWorker.perform_async("Imported #{articles.length} articles for #{@user.username} from #{@rss_feed.url}")
      end

      articles
    end

    def item_previously_imported?(item)
      feed_source_url = item.url.strip.split("?source=")[0]
      @rss_feed.rss_feed_items.where(item_url: feed_source_url).exists?
    end

    def report_error(error, item: nil)
      Rails.logger.error(
        "feeds::import_from_rss_feed::error::#{error.class}::#{error.message}",
        rss_feed_id: @rss_feed.id,
        user_id: @user.id,
        item_url: item&.url
      )
    end

    def subscribe_author_to_comments(user, article)
      NotificationSubscription.create!(
        user: user,
        notifiable_id: article.id,
        notifiable_type: "Article",
        config: "all_comments",
      )
    end
  end
end
