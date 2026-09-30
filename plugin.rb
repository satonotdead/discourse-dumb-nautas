# frozen_string_literal: true

# name: discourse-dumb-nautas
# about: discourse-dumb-nautas — Criptonautas' maintained edition of JtechTools, the JTech Forums all-in-one plugin. Reaction controls, alternate SMTP relay, mini-mod and moderator tooling, the Dumbcourse app, translator tweaks, smart search, desktop pop-ups, username-based default avatars, and the Telegram chat bridge.
# version: 0.4.0
# authors: TripleU, Shalom_Karr, Ars18
# url: https://github.com/satonotdead/discourse-dumb-nautas
# required_version: 3.0.0

# Smart-search synonym backend — rwordnet ships the WordNet lexical DB
# (~117K English words, ~8MB) inside the gem. Pure-Ruby, no external
# C extensions, no network calls.
gem "rwordnet", "2.0.0", require: false

# Master gate. Each sub-plugin keeps its own enable setting (e.g.
# discourse_no_likes_enabled, mini_mod_enabled, mod_categories_enabled,
# dumbcourse_enabled, discourse_another_email_enabled, smart_search_enabled,
# discourse_username_avatar_enabled) for fine-grained control.
enabled_site_setting :jtech_enabled

# `depends_on` in settings.yml only hides settings in the admin UI; the code
# still read each switch on its own, so a feature kept running with its parent
# (or jtech_enabled) off. Every boolean switch here now reads false while any
# of its parent switches in this plugin is off; switches without a parent
# follow jtech_enabled. Stored values and the admin UI are untouched, and the
# client settings go through the same readers, so the front end agrees.
module ::JtechSwitches
  PARENTS =
    begin
      all =
        YAML
          .safe_load(File.read(File.expand_path("config/settings.yml", __dir__)))
          .values
          .grep(Hash)
          .reduce({}, :merge)
      switches = all.select { |_, o| o.is_a?(Hash) && [true, false].include?(o["default"]) }
      switches
        .except("jtech_enabled")
        .to_h do |name, o|
          parents = Array(o["depends_on"]) & switches.keys
          [name, parents.empty? ? ["jtech_enabled"] : parents]
        end
    end

  GATE =
    Module.new do
      PARENTS.each do |name, parents|
        define_method(name) { |*args| super(*args) && parents.all? { |p| public_send(p) } }
      end
    end
end

# SiteSetting only exists once Rails has loaded, not while plugin.rb runs.
after_initialize { SiteSetting.singleton_class.prepend(::JtechSwitches::GATE) }

# Load each sub-plugin's body in the Plugin::Instance context so that all
# Discourse plugin DSL methods — after_initialize, on(:event), register_asset,
# register_svg_icon, add_to_serializer, reloadable_patch, register_html_builder,
# require_relative for nested lib files, etc. — work exactly as they did in the
# original standalone plugin.
#
# Each sub_*.rb file is a faithful copy of its original plugin.rb body
# (magic-header comments and the top-level enabled_site_setting call stripped).
# Settings, locales, lib/, app/, db/migrate, and assets/ from every sub-plugin
# have been merged into this plugin's standard Discourse layout.
%w[
  dislike
  another_smtp
  mini_mod
  mod_categories
  dumbcourse
  translator_tweaks
  smart_search
  popup_notifications
  disteleplus
  username_avatar
].each do |sub|
  path = File.expand_path("sub_plugins/#{sub}.rb", __dir__)
  instance_eval(File.read(path), path, 1)
end
