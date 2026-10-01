# frozen_string_literal: true

module ::Nautas
  class CategoryChecklistController < ::ApplicationController
    requires_plugin "jtech-tools"
    requires_login

    before_action :ensure_enabled
    before_action :ensure_staff, only: %i[show update destroy]

    # The checklist the current user owes before posting: in `category_id`
    # for a new topic, or in the category of `topic_id` for a reply.
    def owed
      category =
        if params[:topic_id].present?
          topic = Topic.find_by(id: params[:topic_id])
          topic.category if topic && guardian.can_see_topic?(topic)
        else
          Category.find_by(id: params[:category_id])
        end
      category = nil if category && !guardian.can_see_category?(category)
      render json: { checklist: NautasCategoryChecklist.owed(current_user, category) }
    end

    def show
      render json: checklist_json(NautasCategoryChecklist.config(category))
    end

    def update
      items = NautasCategoryChecklist.clean_items(params[:items])
      raise Discourse::InvalidParameters.new(:items) if items.empty?

      current = NautasCategoryChecklist.config(category) || {}
      version = current["version"].to_i
      version += 1 if version.zero? || params[:reask].to_s == "true"
      max_tl = params[:max_tl].presence&.to_i || 4
      raise Discourse::InvalidParameters.new(:max_tl) unless (0..4).cover?(max_tl)

      category.custom_fields[NautasCategoryChecklist::FIELD] = {
        "items" => items,
        "button_label" =>
          params[:button_label].to_s.strip.first(NautasCategoryChecklist::MAX_BUTTON_LABEL),
        "max_tl" => max_tl,
        "version" => version,
        "updated_at" => Time.zone.now.iso8601,
      }
      category.save_custom_fields(true)
      render json: checklist_json(NautasCategoryChecklist.config(category))
    end

    def destroy
      category.custom_fields.delete(NautasCategoryChecklist::FIELD)
      category.save_custom_fields(true)
      render json: success_json
    end

    private

    def category
      @category ||=
        Category
          .find_by(id: params[:category_id])
          .tap { |c| raise Discourse::NotFound if c.nil? || !guardian.can_see_category?(c) }
    end

    def ensure_enabled
      raise Discourse::NotFound unless NautasCategoryChecklist.enabled?
    end

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user.staff?
    end

    def checklist_json(config)
      config ||= {}
      {
        items: config["items"] || [],
        button_label: config["button_label"].to_s,
        max_tl: config.fetch("max_tl", 4).to_i,
        version: config["version"].to_i,
        updated_at: config["updated_at"],
      }
    end
  end
end
