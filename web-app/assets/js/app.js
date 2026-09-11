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
import {hooks as colocatedHooks} from "phoenix-colocated/web_app"
import topbar from "../vendor/topbar.cjs"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const composer = {
  mounted() {
    this.activeIndex = 0
    this.textarea = this.el.querySelector("#composer-message")
    this.picker = this.el.querySelector("#slash-command-picker")
    this.handleInput = () => this.filterCommands()
    this.handleKeydown = event => this.handleComposerKeydown(event)
    this.handleMouseDown = event => event.preventDefault()
    this.handleClick = event => {
      const option = event.target.closest("[data-slash-command]")
      if (option) this.insertCommand(option.dataset.slashCommand)
    }

    this.textarea.addEventListener("input", this.handleInput)
    this.el.addEventListener("keydown", this.handleKeydown)
    this.el.addEventListener("mousedown", this.handleMouseDown)
    this.el.addEventListener("click", this.handleClick)
    this.filterCommands()
  },
  updated() {
    this.textarea = this.el.querySelector("#composer-message")
    this.picker = this.el.querySelector("#slash-command-picker")
    this.filterCommands()
  },
  destroyed() {
    this.textarea.removeEventListener("input", this.handleInput)
    this.el.removeEventListener("keydown", this.handleKeydown)
    this.el.removeEventListener("mousedown", this.handleMouseDown)
    this.el.removeEventListener("click", this.handleClick)
  },
  commandOptions() {
    return Array.from(this.el.querySelectorAll("[data-slash-command]"))
  },
  visibleOptions() {
    return this.commandOptions().filter(option => !option.hidden)
  },
  filterCommands() {
    const query = this.textarea?.value.match(/^\/(\S*)/)?.[1].toLowerCase()
    if (query === undefined) return
    this.picker.hidden = false

    this.commandOptions().forEach(option => {
      const text = `${option.dataset.slashCommand} ${option.textContent}`.toLowerCase()
      option.hidden = !text.includes(query)
    })
    this.activeIndex = 0
    this.updateActiveOption()
  },
  updateActiveOption() {
    const options = this.visibleOptions()
    options.forEach((option, index) => option.classList.toggle("bg-base-200", index === this.activeIndex))
  },
  insertCommand(command) {
    const value = this.textarea.value
    const match = value.match(/^\/\S*/)
    if (!match) return

    const next = `/${command}${value.slice(match[0].length)}`
    this.textarea.value = next
    this.textarea.setSelectionRange(command.length + 1, command.length + 1)
    this.textarea.dispatchEvent(new Event("input", {bubbles: true}))
    this.textarea.focus()
  },
  handleComposerKeydown(event) {
    const options = this.visibleOptions()
    if (options.length && ["ArrowDown", "ArrowUp"].includes(event.key)) {
      event.preventDefault()
      this.activeIndex = (this.activeIndex + (event.key === "ArrowDown" ? 1 : options.length - 1)) % options.length
      this.updateActiveOption()
      return
    }
    if (options.length && ["Enter", "Tab"].includes(event.key) && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.insertCommand(options[this.activeIndex].dataset.slashCommand)
      return
    }
    if (event.key === "Escape") {
      this.picker.hidden = true
      return
    }
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    const sendButton = this.el.querySelector("button[name='behavior'][value='send']")
    if (!sendButton || sendButton.disabled) return

    event.preventDefault()
    this.el.requestSubmit(sendButton)
  },
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, Composer: composer},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

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

