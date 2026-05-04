// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js";

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/poker";
import topbar from "../vendor/topbar";
import { PokerCanvas } from "./poker_canvas.js";

const BlindCountdown = {
  mounted() {
    this.startCountdown();
  },
  updated() {
    this.startCountdown();
  },
  destroyed() {
    if (this.timer) clearInterval(this.timer);
  },
  startCountdown() {
    if (this.timer) clearInterval(this.timer);

    const tick = () => {
      const startedAt = new Date(this.el.dataset.levelStartedAt).getTime();
      const duration = parseInt(this.el.dataset.levelDuration) * 1000;
      const endsAt = startedAt + duration;
      const remaining = Math.max(0, endsAt - Date.now());
      const totalSeconds = Math.ceil(remaining / 1000);
      const minutes = Math.floor(totalSeconds / 60);
      const seconds = totalSeconds % 60;
      this.el.textContent = `${minutes}:${seconds.toString().padStart(2, "0")}`;

      if (remaining <= 0 && this.timer) {
        clearInterval(this.timer);
      }
    };

    tick();
    this.timer = setInterval(tick, 1000);
  },
};

const AutoClearFlash = {
  mounted() {
    let ignoredIDs = ["client-error", "server-error"];
    if (ignoredIDs.includes(this.el.id)) return;

    let hideAfter = 2000;
    let clearAfter = hideAfter + 300;

    setTimeout(() => {
      this.el.style.opacity = 0;
      this.el.style.transition = "opacity 0.3s ease-out";
    }, hideAfter);

    setTimeout(() => {
      this.pushEvent("lv:clear-flash");
    }, clearAfter);
  },
};

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, PokerCanvas, AutoClearFlash, BlindCountdown },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });

const pageLoading = document.getElementById("page-loading");
window.addEventListener("phx:page-loading-start", ({ detail: { kind } }) => {
  topbar.show(300);
  if (kind === "redirect") pageLoading?.classList.remove("hidden");
});
window.addEventListener("phx:page-loading-stop", () => {
  topbar.hide();
  pageLoading?.classList.add("hidden");
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// liveSocket.enableDebug();
// liveSocket.enableLatencySim(1000); // enabled for duration of browser session
liveSocket.disableLatencySim();
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
