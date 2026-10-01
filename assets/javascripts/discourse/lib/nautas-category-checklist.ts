import type Owner from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { CREATE_TOPIC } from "discourse/models/composer";
import type ModalService from "discourse/services/modal";
import ModFirstPostChecklist from "../components/mod-first-post-checklist";
import type { OwedChecklist } from "./first-post-checklist";
import { type PrecheckComposer, REPLY_ACTION } from "./precheck-prompt";

type CategoryComposer = PrecheckComposer & {
  categoryId?: number | null;
};

// Asks for the category checklist (once per category) before a new topic
// or reply in a category that has one. Resolves when nothing is owed.
export async function categoryChecklistGate(
  owner: Owner,
  composer: CategoryComposer
): Promise<void> {
  let query: string;
  if (composer.action === REPLY_ACTION && composer.topic?.id) {
    query = `topic_id=${encodeURIComponent(composer.topic.id)}`;
  } else if (composer.action === CREATE_TOPIC && composer.categoryId) {
    query = `category_id=${encodeURIComponent(composer.categoryId)}`;
  } else {
    return;
  }

  let checklist: OwedChecklist | null = null;
  try {
    const result = (await ajax(
      `/nautas/category-checklist/owed.json?${query}`
    )) as {
      checklist: OwedChecklist | null;
    };
    checklist = result.checklist;
  } catch {
    // The server still refuses the post if a checklist is owed.
    return;
  }
  if (!checklist) {
    return;
  }

  const modal = owner.lookup("service:modal") as ModalService;
  return new Promise<void>((resolve, reject) => {
    modal.show(ModFirstPostChecklist, {
      model: { checklist, onAccept: resolve, onCancel: reject },
    });
  });
}
