// Leaderboard from discourse-gamification (our addition). The board
// shown is the one named by dumbcourse_leaderboard_id; 0 hides the screen.

import { errorMessage } from "../api.ts";
import { go } from "../app.ts";
import { swr } from "../cache.ts";
import { settings } from "../config.ts";
import { html } from "../html.ts";
import { focusContent } from "../nav.ts";
import { href, type RouteContext } from "../router.ts";
import { avatar } from "../site.ts";
import { useScreen } from "./common.ts";

interface Ranked {
  username: string;
  avatar_template: string;
  position: number;
  total_score: number;
}

interface LeaderboardResponse {
  leaderboard?: { name?: string };
  users?: Ranked[];
  personal?: { user?: Ranked };
}

export function leaderboardRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  s.title("Leaderboard", { back: true });
  if (!settings.leaderboardId) {
    s.empty("No leaderboard here.", "star");
    return Promise.resolve();
  }
  s.loading();
  let first = true;
  return swr<LeaderboardResponse>(
    `/leaderboard/${settings.leaderboardId}.json`,
    (d) => {
      const users = d.users || [];
      if (d.leaderboard && d.leaderboard.name)
        s.title(d.leaderboard.name, { back: true });
      if (!users.length) {
        s.empty("No scores yet.", "star");
        return;
      }
      const me = d.personal && d.personal.user;
      s.render(
        html`${me && me.position
            ? html`<p class="notice">
                Your rank: #${me.position} · ${me.total_score} pts
              </p>`
            : ""}
          <ul class="rows">
            ${users.map(
              (u) =>
                html`<li>
                  <a
                    class="row"
                    href="${href("/u/" + encodeURIComponent(u.username))}"
                    data-key="u${u.position}"
                  >
                    ${avatar(u.avatar_template, 28)}
                    <div class="row-main">
                      <div class="row-title">#${u.position} ${u.username}</div>
                      <div class="row-meta">
                        <span>${u.total_score} pts</span>
                      </div>
                    </div></a
                  >
                </li>`
            )}
          </ul>`
      );
      if (first && !ctx.restore) focusContent(".row");
      first = false;
    }
  ).catch((e: unknown) =>
    s.error(errorMessage(e), () => go(ctx.path, { replace: true }))
  );
}
