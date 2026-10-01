import { withPluginApi } from "discourse/lib/plugin-api";

// The nav registry is keyed on AdminPlugin#id, which is the plugin's
// DIRECTORY name on the server — not the metadata name. The repo, the
// clone folder and the plugin name are all `discourse-dumb-nautas`.
const PLUGIN_IDS = ["discourse-dumb-nautas"];

// One tab per sub-plugin, in plugin.rb load order, plus core's own
// all-settings tab kept last (if omitted, core unshifts it to position 0
// with its default label). The index route redirects to the first
// non-settings link, so Dislike is the landing tab.
const LINKS = [
  {
    label: "discourse_dumb_nautas.admin.tabs.dislike",
    route: "adminPlugins.show.discourse-dumb-nautas-dislike",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.smtp",
    route: "adminPlugins.show.discourse-dumb-nautas-smtp",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.mini_mod",
    route: "adminPlugins.show.discourse-dumb-nautas-mini-mod",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.mod",
    route: "adminPlugins.show.discourse-dumb-nautas-mod",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.dumbcourse",
    route: "adminPlugins.show.discourse-dumb-nautas-dumbcourse",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.translator",
    route: "adminPlugins.show.discourse-dumb-nautas-translator",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.smart_search",
    route: "adminPlugins.show.discourse-dumb-nautas-smart-search",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.popups",
    route: "adminPlugins.show.discourse-dumb-nautas-popups",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.disteleplus",
    route: "adminPlugins.show.discourse-dumb-nautas-disteleplus",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.username_avatar",
    route: "adminPlugins.show.discourse-dumb-nautas-username-avatar",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.reqpm",
    route: "adminPlugins.show.discourse-dumb-nautas-reqpm",
  },
  {
    label: "discourse_dumb_nautas.admin.tabs.all_settings",
    route: "adminPlugins.show.settings",
  },
];

export default {
  name: "discourse-dumb-nautas-admin-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }
    withPluginApi((api) => {
      PLUGIN_IDS.forEach((id) => {
        api.setAdminPluginIcon(id, "wrench");
        // Fresh copy per id: the nav manager mutates the stored array
        // (unshift of the settings link when absent).
        api.addAdminPluginConfigurationNav(id, [...LINKS]);
      });
    });
  },
};
