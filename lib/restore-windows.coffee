{$} = require 'atom'
crypto = require 'crypto'
fs = require 'fs-plus'
path = require 'path'

module.exports =
  config:
    regardOperationsAsQuitWhileMillisecond:
      type: 'integer'
      default: 5000
      description: 'Projects will be restored that was closed near past than this threshold before latest project was closed.'

  activate: (state) ->
    if atom.inDevMode()
      console.log "restore-windows stopped restoring because atom is in development mode."
      return
    if atom.inSpecMode()
      console.log "restore-windows stopped restoring because atom is in development mode."
      return
    @initializeDirectory(atom.getConfigDirPath())
    $(window).on 'beforeunload', => @onBeforeUnload()
    atom.project.on 'projectPath-changed', => @projectPathChanged()
    @restoreWindows()
    @projectPathChanged()

  # stateFiles will be stored in configDirPath (default: atom.getConfigDirPath())
  initializeDirectory: (configDirPath = atom.getConfigDirPath())->
    @mayBeRestoredPath = path.join(configDirPath, 'restore-windows', 'mayBeRestored')
    fs.makeTreeSync(@mayBeRestoredPath) unless fs.existsSync(@mayBeRestoredPath)
    @openedPath = path.join(configDirPath, 'restore-windows', 'opened')
    fs.makeTreeSync(@openedPath) unless fs.existsSync(@openedPath)

  onBeforeUnload: ->
    if @projectPath?
      @removeFromOpened(@projectPath)
      @addToMayBeRestored(@projectPath)
    @removeOutdatedMayBeRestored()
    return true

  projectPathChanged: ->
    @removeFromOpened(@projectPath) if @projectPath?
    @projectPath = atom.project.getPath()
    @addToOpened(@projectPath) if @projectPath?

  addToMayBeRestored: (projectPath = @projectPath) ->
    fs.writeFileSync(path.join(@mayBeRestoredPath, hashedFilename(projectPath)), projectPath)

  removeOutdatedMayBeRestored: ->
    threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
    mayBeRestored = @readMayBeRestored()
    mayBeRestored.forEach (x) -> fs.unlinkSync(x.restoreFilePath) if x.timestampDiff > threshold

  addToOpened: (projectPath = @projectPath) ->
    fs.writeFileSync(path.join(@openedPath, hashedFilename(projectPath)), projectPath)

  removeFromOpened: (projectPath = @projectPath) ->
    fs.unlinkSync(path.join(@openedPath, hashedFilename(projectPath)))

  restoreWindows: ->
    if fs.readdirSync(@openedPath)?.length == 0
      pathsToReopen = @getPathsToReopen()

      if atom.project.getPath()?
        pathsToReopen = pathsToReopen.filter (path) -> path isnt atom.project.getPath()

      if pathsToReopen.length > 0
        atom.open({pathsToOpen: pathsToReopen, newWindow: true})
        atom.close() unless atom.project.getPath()?

    else
      console.log 'Did not restore because `openedPath` is not empty.'

  getPathsToReopen: ->
    threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
    mayBeRestored = @readMayBeRestored()
    mayBeRestored.forEach (x) -> fs.unlinkSync(x.restoreFilePath)
    mayBeRestored
      .filter (x) -> x.timestampDiff < threshold and fs.existsSync(x.projectPath)
      .map (x) -> x.projectPath

  readMayBeRestored: ->
    latestTimestamp = 0
    fs.readdirSync(@mayBeRestoredPath)
      .map((filename) ->
        if isValidHashedFilename(filename)
          restoreFilePath = path.join(@mayBeRestoredPath, filename)
          if stat = fs.statSyncNoException(restoreFilePath)
            projectPath = fs.readFileSync(restoreFilePath, 'utf8')
            timestamp = stat.mtime.valueOf()
            latestTimestamp = timestamp if timestamp > latestTimestamp
            {restoreFilePath: restoreFilePath, projectPath: projectPath, timestamp: timestamp}
      , @)
      .filter (x) -> x
      .map (x) ->
        x.timestampDiff = latestTimestamp - x.timestamp
        x

hashedFilename = (projectPath) ->
  # ignore hash collisions
  crypto.createHash('md5').update(projectPath).digest('hex')

isValidHashedFilename = (filename) ->
  filename.match(/^[0-9a-f]{32}$/)?
