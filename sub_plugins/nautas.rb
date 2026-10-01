# frozen_string_literal: true
# Power Tools Nautas edition glue: behaviour our forum needs on top of upstream,
# kept in one file so upstream merges rarely touch it.

require_relative "../lib/nautas/category_checklist"

Discourse::Application.routes.append do
  scope "/nautas/category-checklist", module: "nautas", defaults: { format: :json } do
    get "/owed" => "category_checklist#owed"
    get "/:category_id" => "category_checklist#show", :constraints => { category_id: /\d+/ }
    put "/:category_id" => "category_checklist#update", :constraints => { category_id: /\d+/ }
    delete "/:category_id" => "category_checklist#destroy", :constraints => { category_id: /\d+/ }
  end
end

# The composer asks for the category checklist first; this also holds for
# /dumb and the API. Approving a queued post skips it (core skips this event
# when it skips validations).
on(:before_create_post) do |post, opts|
  next unless NautasCategoryChecklist.enabled?
  category = NautasCategoryChecklist.category_for(post, opts)
  next unless NautasCategoryChecklist.owed(post.user, category)
  post.errors.add(:base, I18n.t("nautas.category_checklist.required", category: category.name))
end

after_initialize do
  register_category_custom_field_type(NautasCategoryChecklist::FIELD, :json)
  register_user_custom_field_type(NautasCategoryChecklist::USER_FIELD, :json)

  # Mod whispers are regular posts with an audience. A core whisper flag
  # carried over by the composer (replying to a core whisper, e.g. inside a
  # category-lockdown topic) would hide the post from its non-staff targets,
  # so a post that became a mod whisper is always a regular post.
  module ::DiscourseModCategories::NautasWhisperPostType
    def prepare_new_post!(post, opts)
      result = super
      if post.custom_fields.key?(::DiscourseModCategories::POST_WHISPER_TARGETS_FIELD) &&
           post.post_type == ::Post.types[:whisper]
        post.post_type = ::Post.types[:regular]
      end
      result
    end
  end
  ::DiscourseModCategories::Whisper.singleton_class.prepend(
    ::DiscourseModCategories::NautasWhisperPostType,
  )

  # discourse-category-lockdown turns every reply in a "keep replies private"
  # category into a core whisper in before_create_tasks. The audience field
  # above is set earlier (PostCreator#setup_post), so lockdown can leave mod
  # whispers alone.
  if defined?(::CategoryLockdown) && ::CategoryLockdown.respond_to?(:whisper_reply?)
    module ::DiscourseModCategories::LockdownWhisperReplyPatch
      def whisper_reply?(post)
        if post.custom_fields.key?(::DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
          return false
        end
        super
      end
    end
    ::CategoryLockdown.singleton_class.prepend(::DiscourseModCategories::LockdownWhisperReplyPatch)
  end

  # Accepting a category checklist goes through the same endpoint and audit
  # log as the other checklists, so the composer modal needs no changes.
  module ::NautasCategoryChecklist::ControllerPatch
    def accept
      return super unless params[:kind].to_s == "category"
      raise Discourse::NotFound unless NautasCategoryChecklist.enabled?
      RateLimiter.new(current_user, "mod-checklist-accept", 20, 1.minute).performed!
      category = Category.find_by(id: params[:id])
      raise Discourse::NotFound if category.nil? || !guardian.can_see_category?(category)
      raise Discourse::NotFound unless NautasCategoryChecklist.config(category)
      if NautasCategoryChecklist.accept!(current_user, category, params[:version])
        version = NautasCategoryChecklist.accepted_versions(current_user)[category.id.to_s]
        append_log_entry(version, kind: "category", id: category.id.to_s)
      end
      render json: success_json
    end

    private

    def acceptance_log
      entries = super
      ids = entries.filter_map { |e| e[:checklist_id].to_i if e[:kind] == "category" }
      names = Category.where(id: ids.uniq).pluck(:id, :name).to_h
      entries.each do |e|
        next unless e[:kind] == "category"
        e[:checklist_name] = I18n.t(
          "nautas.category_checklist.log_name",
          category: names[e[:checklist_id].to_i] || e[:checklist_id],
        )
      end
    end
  end
  ::DiscourseModCategories::ChecklistController.prepend(::NautasCategoryChecklist::ControllerPatch)
end
