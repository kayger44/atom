{View, $} = require 'space-pen'
React = require 'react-atom-fork'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
Editor = require './editor'
EditorComponent = require './editor-component'

module.exports =
class ReactEditorView extends View
  @configDefaults:
    fontFamily: ''
    fontSize: 16
    lineHeight: 1.3
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    normalizeIndentOnPaste: true
    nonWordCharacters: "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
    preferredLineLength: 80
    tabLength: 2
    softWrap: false
    softTabs: true
    softWrapAtPreferredLineLength: false
    scrollSensitivity: 40
    useHardwareAcceleration: true

  @content: (params) ->
    attributes = params.attributes ? {}
    attributes.class = 'editor react editor-colors'
    attributes.tabIndex = -1
    @div attributes

  focusOnAttach: false

  constructor: (editorOrParams, props) ->
    super

    if editorOrParams instanceof Editor
      @editor = editorOrParams
    else
      {@editor, mini, placeholderText} = editorOrParams
      props ?= {}
      props.mini = mini
      props.placeholderText = placeholderText
      @editor ?= new Editor
        buffer: new TextBuffer
        softWrap: false
        tabLength: 2
        softTabs: true
        mini: mini

    props = defaults({@editor, parentView: this}, props)
    @component = React.renderComponent(EditorComponent(props), @element)

    node = @component.getDOMNode()

    @scrollView = $(node).find('.scroll-view')
    @underlayer = $(node).find('.highlights').addClass('underlayer')
    @overlayer = $(node).find('.lines').addClass('overlayer')
    @hiddenInput = $(node).find('.hidden-input')

    # FIXME: there should be a better way to deal with the gutter element
    @subscribe atom.config.observe 'editor.showLineNumbers', =>
      @gutter = $(node).find('.gutter')

      @gutter.removeClassFromAllLines = (klass) =>
        @gutter.find('.line-number').removeClass(klass)

      @gutter.getLineNumberElement = (bufferRow) =>
        @gutter.find("[data-buffer-row='#{bufferRow}']")

      @gutter.addClassToLine = (bufferRow, klass) =>
        lines = @gutter.find("[data-buffer-row='#{bufferRow}']")
        lines.addClass(klass)
        lines.length > 0

    @on 'focus', =>
      if @component?
        @component.onFocus()
      else
        @focusOnAttach = true

  getEditor: -> @editor

  getModel: -> @editor

  Object.defineProperty @::, 'lineHeight', get: -> @editor.getLineHeightInPixels()
  Object.defineProperty @::, 'charWidth', get: -> @editor.getDefaultCharWidth()
  Object.defineProperty @::, 'firstRenderedScreenRow', get: -> @component.getRenderedRowRange()[0]
  Object.defineProperty @::, 'lastRenderedScreenRow', get: -> @component.getRenderedRowRange()[1]
  Object.defineProperty @::, 'active', get: -> @is(@getPane()?.activeView)
  Object.defineProperty @::, 'isFocused', get: -> @component?.state.focused
  Object.defineProperty @::, 'mini', get: -> @component?.props.mini

  afterAttach: (onDom) ->
    return unless onDom
    return if @attached
    @attached = true
    @component.pollDOM()
    @focus() if @focusOnAttach

    @addGrammarScopeAttribute()
    @subscribe @editor, 'grammar-changed', =>
      @addGrammarScopeAttribute()

    @trigger 'editor:attached', [this]

  addGrammarScopeAttribute: ->
    grammarScope = @editor.getGrammar()?.scopeName?.replace(/\./g, ' ')
    @attr('data-grammar', grammarScope)

  scrollTop: (scrollTop) ->
    if scrollTop?
      @editor.setScrollTop(scrollTop)
    else
      @editor.getScrollTop()

  scrollLeft: (scrollLeft) ->
    if scrollLeft?
      @editor.setScrollLeft(scrollLeft)
    else
      @editor.getScrollLeft()

  scrollToBottom: ->
    @editor.setScrollBottom(Infinity)

  scrollToScreenPosition: (screenPosition, options) ->
    @editor.scrollToScreenPosition(screenPosition, options)

  scrollToBufferPosition: (bufferPosition, options) ->
    @editor.scrollToBufferPosition(bufferPosition, options)

  scrollToCursorPosition: ->
    @editor.scrollToCursorPosition()

  scrollToPixelPosition: (pixelPosition) ->
    screenPosition = screenPositionForPixelPosition(pixelPosition)
    @editor.scrollToScreenPosition(screenPosition)

  pixelPositionForBufferPosition: (bufferPosition) ->
    @editor.pixelPositionForBufferPosition(bufferPosition)

  pixelPositionForScreenPosition: (screenPosition) ->
    @editor.pixelPositionForScreenPosition(screenPosition)

  appendToLinesView: (view) ->
    view.css('position', 'absolute')
    view.css('z-index', 1)
    @find('.lines').prepend(view)

  beforeRemove: ->
    return unless @attached
    @attached = false
    React.unmountComponentAtNode(@element) if @component.isMounted()
    @trigger 'editor:detached', this

  # Public: Split the editor view left.
  splitLeft: ->
    pane = @getPane()
    pane?.splitLeft(pane?.copyActiveItem()).activeView

  # Public: Split the editor view right.
  splitRight: ->
    pane = @getPane()
    pane?.splitRight(pane?.copyActiveItem()).activeView

  # Public: Split the editor view up.
  splitUp: ->
    pane = @getPane()
    pane?.splitUp(pane?.copyActiveItem()).activeView

  # Public: Split the editor view down.
  splitDown: ->
    pane = @getPane()
    pane?.splitDown(pane?.copyActiveItem()).activeView

  getPane: ->
    @parent('.item-views').parents('.pane').view()

  hide: ->
    super
    @pollComponentDOM()

  show: ->
    super
    @pollComponentDOM()

  pollComponentDOM: ->
    return unless @component?
    valueToRestore = @component.performSyncUpdates
    @component.performSyncUpdates = true
    @component.pollDOM()
    @component.performSyncUpdates = valueToRestore

  pageDown: ->
    @editor.pageDown()

  pageUp: ->
    @editor.pageUp()

  getFirstVisibleScreenRow: ->
    @editor.getVisibleRowRange()[0]

  getLastVisibleScreenRow: ->
    @editor.getVisibleRowRange()[1]

  getFontFamily: ->
    @component?.getFontFamily()

  setFontFamily: (fontFamily) ->
    @component?.setFontFamily(fontFamily)

  getFontSize: ->
    @component?.getFontSize()

  setFontSize: (fontSize) ->
    @component?.setFontSize(fontSize)

  setWidthInChars: (widthInChars) ->
    @component.getDOMNode().style.width = (@editor.getDefaultCharWidth() * widthInChars) + 'px'

  setLineHeight: (lineHeight) ->
    @component.setLineHeight(lineHeight)

  setShowIndentGuide: (showIndentGuide) ->
    @component.setShowIndentGuide(showIndentGuide)

  setSoftWrap: (softWrap) ->
    @editor.setSoftWrap(softWrap)

  setShowInvisibles: (showInvisibles) ->
    @component.setShowInvisibles(showInvisibles)

  toggleSoftWrap: ->
    @editor.toggleSoftWrap()

  toggleSoftTabs: ->
    @editor.toggleSoftTabs()

  getText: ->
    @editor.getText()

  setText: (text) ->
    @editor.setText(text)

  insertText: (text) ->
    @editor.insertText(text)

  isInputEnabled: ->
    @component.isInputEnabled()

  setInputEnabled: (inputEnabled) ->
    @component.setInputEnabled(inputEnabled)

  requestDisplayUpdate: -> # No-op shim for find-and-replace

  updateDisplay: ->        # No-op shim for package specs

  resetDisplay: ->         # No-op shim for package specs

  redraw: ->               # No-op shim

  setPlaceholderText: (placeholderText) ->
    if @component?
      @component.setProps({placeholderText})
    else
      @props.placeholderText = placeholderText

  lineElementForScreenRow: (screenRow) ->
    $(@component.lineNodeForScreenRow(screenRow))
