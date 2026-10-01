import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import type { ComponentLike } from "@glint/template";
import UntypedComboBox from "select-kit/components/combo-box";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  type TrustLevelOption,
  trustLevelOptions,
} from "../../lib/trust-level-options";

interface ComboBoxSignature {
  Element: HTMLElement;
  Args: {
    value: string;
    content: TrustLevelOption[];
    onChange: (value: string) => void;
  };
}
const ComboBox = UntypedComboBox as unknown as ComponentLike<ComboBoxSignature>;

interface ChecklistResponse {
  items: { label: string; url: string }[];
  button_label: string;
  max_tl: number;
  version: number;
}

interface Signature {
  Args: { outletArgs: { category: { id?: number } } };
}

// "Label | https://link" per line <-> [{ label, url }].
function toText(items: ChecklistResponse["items"]): string {
  return items
    .map((i) => (i.url ? `${i.label} | ${i.url}` : i.label))
    .join("\n");
}

function toItems(text: string): { label: string; url: string }[] {
  return text
    .split("\n")
    .map((line) => {
      const at = line.lastIndexOf("|");
      const url = at < 0 ? "" : line.slice(at + 1).trim();
      return /^(https?:\/\/|\/)/i.test(url)
        ? { label: line.slice(0, at).trim(), url }
        : { label: line.trim(), url: "" };
    })
    .filter((i) => i.label);
}

// Category settings: the checklist people accept once before posting in
// this category. Staff only; saves through its own endpoint.
export default class NautasCategoryChecklist extends Component<Signature> {
  static shouldRender(
    args: { category?: { id?: number } | null } | null | undefined,
    context:
      | {
          siteSettings?: {
            mod_categories_enabled?: boolean;
            nautas_category_checklist_enabled?: boolean;
          };
          currentUser?: { staff?: boolean } | null;
        }
      | null
      | undefined
  ): boolean {
    return !!(
      context?.siteSettings?.mod_categories_enabled &&
      context?.siteSettings?.nautas_category_checklist_enabled &&
      context?.currentUser?.staff &&
      args?.category?.id
    );
  }

  @tracked text = "";
  @tracked buttonLabel = "";
  @tracked maxTl = "4";
  @tracked version = 0;
  @tracked reask = false;
  @tracked saving = false;
  @tracked saved = false;
  audienceOptions = trustLevelOptions(true);

  constructor(owner: Owner, args: Signature["Args"]) {
    super(owner, args);
    this.load();
  }

  get url(): string {
    return `/nautas/category-checklist/${this.args.outletArgs.category.id}`;
  }

  apply(data: ChecklistResponse) {
    this.text = toText(data.items);
    this.buttonLabel = data.button_label;
    this.maxTl = String(data.max_tl);
    this.version = data.version;
    this.reask = false;
  }

  async load() {
    try {
      this.apply((await ajax(this.url)) as ChecklistResponse);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  updateText(event: Event) {
    this.text = (event.target as HTMLTextAreaElement).value;
    this.saved = false;
  }

  @action
  updateMaxTl(value: string) {
    this.maxTl = value;
    this.saved = false;
  }

  @action
  async save() {
    this.saving = true;
    try {
      const result = (await ajax(this.url, {
        type: "PUT",
        data: {
          items: toItems(this.text),
          button_label: this.buttonLabel,
          max_tl: this.maxTl,
          reask: this.reask,
        },
      })) as ChecklistResponse;
      this.apply(result);
      this.saved = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async remove() {
    this.saving = true;
    try {
      await ajax(this.url, { type: "DELETE" });
      this.apply({ items: [], button_label: "", max_tl: 4, version: 0 });
      this.saved = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <section class="nautas-category-checklist field">
      <label class="mod-messages-label">
        {{i18n "nautas.category_checklist.title"}}
      </label>
      <textarea
        class="nautas-category-checklist-items"
        placeholder={{i18n "nautas.category_checklist.items_placeholder"}}
        rows="4"
        value={{this.text}}
        {{on "input" this.updateText}}
      ></textarea>

      <label class="mod-messages-label">
        {{i18n "nautas.category_checklist.button_label"}}
      </label>
      <Input
        class="nautas-category-checklist-button-label"
        maxlength="60"
        @value={{this.buttonLabel}}
      />

      <label class="mod-messages-label">
        {{i18n "discourse_mod_categories.audience.label"}}
      </label>
      <ComboBox
        class="nautas-category-checklist-audience"
        @content={{this.audienceOptions}}
        @onChange={{this.updateMaxTl}}
        @value={{this.maxTl}}
      />

      {{#if this.version}}
        <label class="checkbox-label">
          <Input
            class="nautas-category-checklist-reask"
            @checked={{this.reask}}
            @type="checkbox"
          />
          {{i18n "nautas.category_checklist.reask"}}
        </label>
      {{/if}}

      <div class="mod-new-topic-prompt-actions">
        <DButton
          class="btn-primary nautas-category-checklist-save"
          @action={{this.save}}
          @disabled={{this.saving}}
          @label="nautas.category_checklist.save"
        />
        {{#if this.version}}
          <DButton
            class="btn-danger nautas-category-checklist-remove"
            @action={{this.remove}}
            @disabled={{this.saving}}
            @label="nautas.category_checklist.remove"
          />
        {{/if}}
        {{#if this.saved}}
          <span class="mod-saved-indicator">
            {{i18n "discourse_mod_categories.category_settings.saved"}}
          </span>
        {{/if}}
      </div>
    </section>
  </template>
}
