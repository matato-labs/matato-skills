export const composer = {
  mounted() {
    this.activeIndex = 0
    this.pickerDismissed = false
    this.handleInput = () => this.filterCommands()
    this.handleKeydown = event => this.handleComposerKeydown(event)
    this.onMouseDown = event => this.handleMouseDown(event)
    this.onClick = event => this.handleClick(event)

    this.refreshElements()
    this.el.addEventListener("keydown", this.handleKeydown)
    this.el.addEventListener("mousedown", this.onMouseDown)
    this.el.addEventListener("click", this.onClick)
    this.filterCommands()
  },
  updated() {
    this.refreshElements()
    this.filterCommands()
  },
  destroyed() {
    this.textarea.removeEventListener("input", this.handleInput)
    this.el.removeEventListener("keydown", this.handleKeydown)
    this.el.removeEventListener("mousedown", this.onMouseDown)
    this.el.removeEventListener("click", this.onClick)
  },
  refreshElements() {
    const textarea = this.el.querySelector("#composer-message")
    const previousTextarea = this.textarea

    this.textarea = textarea
    this.picker = this.el.querySelector("#slash-command-picker")
    this.emptyMessage = this.el.querySelector("#slash-command-empty")
    if (previousTextarea === textarea) return
    if (previousTextarea) previousTextarea.removeEventListener("input", this.handleInput)

    this.textarea.addEventListener("input", this.handleInput)
  },
  commandOptions() {
    return Array.from(this.el.querySelectorAll("[data-slash-command]"))
  },
  visibleOptions() {
    if (this.picker.hidden) return []
    return this.commandOptions().filter(option => !option.hidden)
  },
  filterCommands() {
    const query = this.textarea.value.match(/^\/(\S*)/)?.[1]?.toLowerCase()
    if (query === undefined) return this.hidePicker()
    if (this.pickerDismissed && this.textarea.value === this.dismissedValue) return this.hidePicker()

    this.pickerDismissed = false
    this.picker.hidden = false
    this.commandOptions().forEach(option => {
      const text = `${option.dataset.slashCommand} ${option.textContent}`.toLowerCase()
      option.hidden = !text.includes(query)
    })
    this.emptyMessage.hidden = this.visibleOptions().length > 0
    this.activeIndex = 0
    this.updateActiveOption()
  },
  hidePicker() {
    this.picker.hidden = true
  },
  updateActiveOption() {
    this.visibleOptions().forEach((option, index) => option.classList.toggle("bg-base-200", index === this.activeIndex))
  },
  handleMouseDown(event) {
    if (event.target.closest("[data-slash-command]")) event.preventDefault()
  },
  handleClick(event) {
    const option = event.target.closest("[data-slash-command]")
    if (option) this.insertCommand(option.dataset.slashCommand)
  },
  insertCommand(command) {
    const value = this.textarea.value
    const match = value.match(/^\/\S*/)
    if (!match) return

    const next = `/${command}${value.slice(match[0].length)}`
    this.pickerDismissed = true
    this.dismissedValue = next
    this.hidePicker()
    this.textarea.value = next
    this.textarea.setSelectionRange(command.length + 1, command.length + 1)
    this.textarea.dispatchEvent(new Event("input", {bubbles: true}))
    this.textarea.focus()
  },
  handleComposerKeydown(event) {
    if (this.handlePickerNavigation(event)) return
    if (this.handlePickerSelection(event)) return
    if (this.handlePickerDismissal(event)) return
    this.submitComposer(event)
  },
  handlePickerNavigation(event) {
    const options = this.visibleOptions()
    if (!options.length || !["ArrowDown", "ArrowUp"].includes(event.key)) return false

    event.preventDefault()
    const direction = event.key === "ArrowDown" ? 1 : options.length - 1
    this.activeIndex = (this.activeIndex + direction) % options.length
    this.updateActiveOption()
    return true
  },
  handlePickerSelection(event) {
    const options = this.visibleOptions()
    if (!options.length || !["Enter", "Tab"].includes(event.key) || event.shiftKey || event.isComposing) return false

    event.preventDefault()
    this.insertCommand(options[this.activeIndex].dataset.slashCommand)
    return true
  },
  handlePickerDismissal(event) {
    if (event.key !== "Escape") return false

    this.pickerDismissed = true
    this.dismissedValue = this.textarea.value
    this.hidePicker()
    return true
  },
  submitComposer(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return

    event.preventDefault()
    this.el.requestSubmit()
  },
}
