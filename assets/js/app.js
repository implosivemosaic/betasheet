// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

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
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/climb_ontario"
import topbar from "../vendor/topbar"

const Hooks = {
  // "Use my location": ask the browser, hand coordinates to the LiveView, which maps them to a place name.
  Locate: {
    mounted() {
      if (!("geolocation" in navigator)) { this.el.hidden = true; return }
      this.el.addEventListener("click", () => {
        this.el.classList.add("pop", "btn-disabled")
        navigator.geolocation.getCurrentPosition(
          pos => { this.pushEvent("located", {lat: pos.coords.latitude, lng: pos.coords.longitude}); this.el.classList.remove("btn-disabled") },
          () => { this.el.classList.remove("btn-disabled"); this.el.title = "Location unavailable" },
          {timeout: 8000, maximumAge: 300000}
        )
      })
      this.el.addEventListener("animationend", () => this.el.classList.remove("pop"))
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#e0783c"}, shadowColor: "rgba(0, 0, 0, .15)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Share this page (ours, not the organizer's): native share sheet on phones, clipboard elsewhere.
document.addEventListener("click", async e => {
  const btn = e.target.closest("[data-share]")
  if (!btn) return
  const {url, title} = btn.dataset
  const label = btn.querySelector("[data-label]")
  if (navigator.share && /Mobi|Android|iPhone/i.test(navigator.userAgent)) {
    try { await navigator.share({title, url}); return } catch (_) { /* fall through to copy */ }
  }
  try {
    await navigator.clipboard.writeText(url)
    label.textContent = "Link copied"
    btn.classList.add("pop")
    setTimeout(() => { label.textContent = "Share" }, 1600)
    btn.addEventListener("animationend", () => btn.classList.remove("pop"), {once: true})
  } catch (_) { window.prompt("Copy this link", url) }
})

// "All listings" returns to the search you came from when there is one.
document.addEventListener("click", e => {
  const back = e.target.closest("[data-back]")
  if (back && document.referrer.startsWith(location.origin + "/") && history.length > 1) {
    e.preventDefault()
    history.back()
  }
})

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

