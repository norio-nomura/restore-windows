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
      console.log "restore-windows stopped restoring because atom is in spec mode."
      return
    @initializeDirectory(atom.getConfigDirPath())
    window.addEventListener 'beforeunload', => @onBeforeUnload()
    atom.project.onDidChangePaths => @projectPathsChanged()
    @restoreWindows()
    @projectPathsChanged()

  # stateFiles will be stored in configDirPath (default: atom.getConfigDirPath())
  initializeDirectory: (configDirPath = atom.getConfigDirPath())->
    @mayBeRestoredPath = path.join(configDirPath, 'restore-windows', 'mayBeRestored')
    fs.makeTreeSync(@mayBeRestoredPath) unless fs.existsSync(@mayBeRestoredPath)
    @openedPath = path.join(configDirPath, 'restore-windows', 'opened')
    fs.makeTreeSync(@openedPath) unless fs.existsSync(@openedPath)

  onBeforeUnload: ->
    if @projectPaths?.length
      @removeFromOpened(@projectPaths)
      @addToMayBeRestored(@projectPaths)
    @removeOutdatedMayBeRestored()
    return true

  projectPathsChanged: ->
    @removeFromOpened(@projectPaths) if @projectPaths?.length > 0
    @projectPaths = atom.project.getPaths()
    @addToOpened(@projectPaths) if @projectPaths?.length > 0

  addToMayBeRestored: (projectPaths = @projectPaths) ->
    fs.writeFileSync(path.join(@mayBeRestoredPath, hashedFilename(projectPaths)), projectPaths.join("\n"))

  removeOutdatedMayBeRestored: ->
    threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
    mayBeRestored = @readMayBeRestored()
    mayBeRestored.forEach (x) -> fs.unlinkSync(x.restoreFilePath) if x.timestampDiff > threshold

  addToOpened: (projectPaths = @projectPaths) ->
    fs.writeFileSync(path.join(@openedPath, hashedFilename(projectPaths)), projectPaths.join("\n"))

  removeFromOpened: (projectPaths = @projectPaths) ->
    fs.unlinkSync(path.join(@openedPath, hashedFilename(projectPaths)))

  restoreWindows: ->
    if fs.readdirSync(@openedPath)?.length == 0
      pathsToReopen = @getPathsToReopen()

      if atom.project.getPaths()?.length > 0
        currentHashedFilename = hashedFilename(atom.project.getPaths())
        pathsToReopen = pathsToReopen.filter (paths) -> hashedFilename(paths) isnt currentHashedFilename

      if pathsToReopen.length > 0
        pathsToReopen.forEach (paths) -> atom.open({pathsToOpen: paths, newWindow: true})
        atom.close() unless atom.project.getPaths()?.length > 0

    else
      console.log 'Did not restore because `openedPath` is not empty.'

  getPathsToReopen: ->
    threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
    mayBeRestored = @readMayBeRestored()
    mayBeRestored.forEach (x) -> fs.unlinkSync(x.restoreFilePath)
    mayBeRestored
      .filter (x) -> x.timestampDiff < threshold and x.projectPaths.some fs.existsSync
      .map (x) -> x.projectPaths

  readMayBeRestored: ->
    latestTimestamp = 0
    fs.readdirSync(@mayBeRestoredPath)
      .map((filename) ->
        if isValidHashedFilename(filename)
          restoreFilePath = path.join(@mayBeRestoredPath, filename)
          if stat = fs.statSyncNoException(restoreFilePath)
            projectPaths = fs.readFileSync(restoreFilePath, 'utf8').split("\n")
            timestamp = stat.mtime.valueOf()
            latestTimestamp = timestamp if timestamp > latestTimestamp
            {restoreFilePath: restoreFilePath, projectPaths: projectPaths, timestamp: timestamp}
      , @)
      .filter (x) -> x
      .map (x) ->
        x.timestampDiff = latestTimestamp - x.timestamp
        x

hashedFilename = (projectPaths) ->
  # ignore hash collisions
  projectPaths
    .map (projectPath) ->
      crypto.createHash('md5').update(projectPath).digest('hex')
    .join "_"

isValidHashedFilename = (filename) ->
  filename.match(/^[0-9a-f]{32}(_[0-9a-f]{32})*$/)?
