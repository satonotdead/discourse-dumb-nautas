import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import type ModalService from "discourse/services/modal";
import type SiteSettings from "discourse/services/site-settings";
import ModChecklistModal from "discourse/plugins/jtech-tools/discourse/components/mod-checklist-modal";

// Opens the first-post and targeted checklist editor from the Mod tab; this
// edition has no sidebar link for it.
export default class NautasChecklistButton extends Component {
  @service declare modal: ModalService;
  @service
  declare siteSettings: SiteSettings & {
    mod_categories_enabled: boolean;
    mod_first_post_checklist_enabled: boolean;
  };

  get show() {
    return (
      this.siteSettings.mod_categories_enabled &&
      this.siteSettings.mod_first_post_checklist_enabled
    );
  }

  @action
  open() {
    this.modal.show(ModChecklistModal, undefined);
  }

  <template>
    {{#if this.show}}
      <DButton
        class="btn-default nautas-checklist-button"
        @action={{this.open}}
        @icon="list-check"
        @label="discourse_mod_categories.first_post_checklist.sidebar_text"
        @title="discourse_mod_categories.first_post_checklist.sidebar_title"
      />
    {{/if}}
  </template>
}
