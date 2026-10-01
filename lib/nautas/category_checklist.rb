# frozen_string_literal: true

# A checklist people accept once per category before they post there (new
# topics and replies). Staff set it on the category; each user's accepted
# version per category is kept on the user.
module ::NautasCategoryChecklist
  FIELD = "nautas_category_checklist"
  USER_FIELD = "nautas_category_checklist_accepted"
  MAX_ITEMS = 20
  MAX_LABEL = 300
  MAX_BUTTON_LABEL = 60

  def self.enabled?
    DiscourseModCategories.enabled? && SiteSetting.nautas_category_checklist_enabled
  end

  def self.config(category)
    raw = category&.custom_fields&.[](FIELD)
    raw = JSON.parse(raw) if raw.is_a?(String)
    return nil unless raw.is_a?(Hash) && raw["items"].is_a?(Array) && raw["items"].any?
    raw
  rescue JSON::ParserError
    nil
  end

  def self.accepted_versions(user)
    map = user.custom_fields[USER_FIELD]
    map = JSON.parse(map) if map.is_a?(String)
    map.is_a?(Hash) ? map : {}
  rescue JSON::ParserError
    {}
  end

  # The checklist `user` still has to accept before posting in `category`,
  # in the shape the checklist modal reads, or nil.
  def self.owed(user, category)
    return nil if !enabled? || user.nil? || category.nil?
    return nil if user.staff? || user.bot?
    checklist = config(category)
    return nil unless checklist
    return nil if user.trust_level > checklist.fetch("max_tl", 4).to_i

    version = checklist["version"].to_i
    return nil if accepted_versions(user)[category.id.to_s].to_i >= version

    {
      kind: "category",
      id: category.id,
      version: version,
      items: checklist["items"],
      button_label: checklist["button_label"].to_s,
      updated_at: checklist["updated_at"],
    }
  end

  def self.accept!(user, category, version)
    checklist = config(category)
    return false unless checklist
    accepted = [version.to_i, checklist["version"].to_i].min
    map = accepted_versions(user)
    return false if map[category.id.to_s].to_i == accepted
    map[category.id.to_s] = accepted
    user.custom_fields[USER_FIELD] = map
    user.save_custom_fields(true)
    true
  end

  # Items as [{ "label", "url" }], dropping blanks and unsafe links.
  def self.clean_items(items)
    Array(items.respond_to?(:values) ? items.values : items)
      .filter_map do |item|
        item = item.to_unsafe_h if item.respond_to?(:to_unsafe_h)
        next unless item.is_a?(Hash)
        label = item["label"].to_s.strip.first(MAX_LABEL)
        next if label.empty?
        url = item["url"].to_s.strip
        url = "" unless url.empty? || url.match?(%r{\A(https?://|/(?!/))}i)
        { "label" => label, "url" => url }
      end
      .first(MAX_ITEMS)
  end

  # The category a new post goes to: the topic's for a reply, the requested
  # one (or Uncategorized) for a new topic.
  def self.category_for(post, opts)
    return nil if opts[:archetype] == Archetype.private_message
    if post.topic
      return nil if post.topic.private_message?
      return post.topic.category
    end
    requested = opts[:category]
    if requested.blank?
      Category.find_by(id: SiteSetting.uncategorized_category_id)
    elsif requested.is_a?(Integer) || requested.to_s.match?(/\A\d+\z/)
      Category.find_by(id: requested)
    else
      Category.find_by(name_lower: requested.to_s.downcase)
    end
  end
end
