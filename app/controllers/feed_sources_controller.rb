class FeedSourcesController < ApplicationController
  before_action :check_suspended
  before_action :authenticate_user!
  before_action :set_feed_source, only: %i[update destroy fetch]
  after_action :verify_authorized

  def create
    authorize current_user, policy_class: UserPolicy
    feed_source = current_user.feed_sources.new(feed_source_params)

    if feed_source.save
      flash[:settings_notice] = I18n.t("users_controller.updated_config")
    else
      flash[:error] = feed_source.errors_as_sentence
    end

    redirect_to dashboard_rss_import_path
  end

  def update
    authorize current_user, policy_class: UserPolicy

    if @feed_source.update(feed_source_params)
      flash[:settings_notice] = I18n.t("users_controller.updated_config")
    else
      flash[:error] = @feed_source.errors_as_sentence
    end

    redirect_to dashboard_rss_import_path
  end

  def destroy
    authorize current_user, policy_class: UserPolicy
    @feed_source.destroy

    flash[:settings_notice] = I18n.t("users_controller.updated_config")
    redirect_to dashboard_rss_import_path
  end

  def fetch
    authorize current_user, policy_class: UserPolicy
    Feeds::ImportArticlesWorker.perform_async([], nil, [@feed_source.id])
    flash[:settings_notice] = I18n.t("users_controller.updated_config")

    redirect_to dashboard_rss_import_path
  end

  private

  def set_feed_source
    @feed_source = current_user.feed_sources.find(params[:id])
  end

  def feed_source_params
    permitted = params.require(:feed_source).permit(
      :url,
      :enabled,
      :feed_mark_canonical,
      :feed_referential_link,
      :fallback_author_id,
      :fallback_organization_id,
    )

    permitted[:fallback_author_id] = current_user.id if permitted[:fallback_author_id].present?
    permitted[:fallback_organization_id] = nil if permitted[:fallback_organization_id].blank?

    permitted
  end
end
