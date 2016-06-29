{CompositeDisposable} = require 'atom'
autoCompleteJSX = require './auto-complete-jsx'
AutoIndent = require './auto-indent'

INTERFILESAVETIME = 1000
LB = 'language-babel'

module.exports =
  config: require './config'

  activate: (state) ->
    @transpiler ?= new (require './transpiler')
    # track any file save events and transpile if babel
    @disposable = new CompositeDisposable
    @textEditors = {}
    @fileSaveTimes = {}

    @disposable.add atom.packages.onDidActivatePackage @isPackageCompatible

    @disposable.add atom.project.onDidChangePaths =>
      @transpiler.stopUnusedTasks()

    @disposable.add atom.workspace.observeTextEditors (textEditor) =>
      @textEditors[textEditor.id] = new CompositeDisposable

      @textEditors[textEditor.id].add textEditor.observeGrammar (grammar) =>
        # Instantiate indentor for language-babel files
        if textEditor.getGrammar().packageName is LB
          @textEditors[textEditor.id].autoIndent = new AutoIndent(textEditor)
        else
          @textEditors[textEditor.id]?.autoIndent?.destroy()
          delete @textEditors[textEditor.id]?.autoIndent?

      @textEditors[textEditor.id].add textEditor.onDidSave (event) =>
        if textEditor.getGrammar().packageName is LB
          filePath = textEditor.getPath()
          lastSaveTime = @fileSaveTimes[filePath] ? 0
          @fileSaveTimes[filePath] = Date.now()
          if  (lastSaveTime < (@fileSaveTimes[filePath] - INTERFILESAVETIME))
            @transpiler.transpile(filePath, textEditor)

      @textEditors[textEditor.id].add textEditor.onDidDestroy () =>
        @textEditors[textEditor.id]?.autoIndent?.destroy()
        delete @textEditors[textEditor.id]?.autoIndent?
        filePath = textEditor.getPath()
        if @fileSaveTimes[filePath]? then delete @fileSaveTimes[filePath]
        @textEditors[textEditor.id].dispose()
        delete @textEditors[textEditor.id]

  deactivate: ->
    @disposable.dispose()
    for id, disposeable of @textEditors
      if @textEditors[id].autoIndent?
        @textEditors[id].autoIndent.destroy()
        delete @textEditors[id].autoIndent
      disposeable.dispose()
    @transpiler.stopAllTranspilerTask()
    @transpiler.disposables.dispose()

  # warns if an activated package is on the incompatible list
  isPackageCompatible: (activedPackage) ->
    incompatiblePackages = ['source-preview-babel', 'source-preview-react', 'react']
    if activedPackage.name in incompatiblePackages
      atom.notifications.addError 'Incompatible Package Detected',
        dismissable: true
        detail: "language-babel has detected the presence of an
                incompatible package named '#{activedPackage.name}'.
                \n \n'#{activedPackage.name}' may cause language-babel to misbehave.
                It is recommended that you disable it or language-babel"

  JSXCompleteProvider: ->
    autoCompleteJSX

  provide:->
    @transpiler
