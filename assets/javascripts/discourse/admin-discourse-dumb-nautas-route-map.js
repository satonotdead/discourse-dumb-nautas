// Child routes for the /admin/plugins/discourse-dumb-nautas config page — one per
// sub-plugin tab. Must live in the MAIN bundle: the Ember router collects
// every `*-route-map` module once at boot, and the admin bundle is a
// staff-gated dynamic import that loads too late.
//
// Route names become adminPlugins.show.discourse-dumb-nautas-*; URLs
// /admin/plugins/discourse-dumb-nautas/<path>. "settings" is reserved (core's own
// all-settings child route) — never name a child route that.
export default {
  resource: "admin.adminPlugins.show",
  map() {
    this.route("discourse-dumb-nautas-dislike", { path: "dislike" });
    this.route("discourse-dumb-nautas-smtp", { path: "smtp" });
    this.route("discourse-dumb-nautas-mini-mod", { path: "mini-mod" });
    this.route("discourse-dumb-nautas-mod", { path: "mod" });
    this.route("discourse-dumb-nautas-dumbcourse", { path: "dumbcourse" });
    this.route("discourse-dumb-nautas-translator", { path: "translator" });
    this.route("discourse-dumb-nautas-smart-search", { path: "smart-search" });
    this.route("discourse-dumb-nautas-popups", { path: "popups" });
    this.route("discourse-dumb-nautas-disteleplus", { path: "disteleplus" });
    this.route("discourse-dumb-nautas-username-avatar", { path: "username-avatar" });
  },
};
