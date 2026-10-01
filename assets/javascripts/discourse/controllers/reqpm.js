import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class ReqpmController extends Controller {
  @tracked tab = null;
  @tracked user = null;
  queryParams = ["tab", "user"];

  @action
  changeTab(tab) {
    this.tab = tab;
    this.user = null;
  }
}
