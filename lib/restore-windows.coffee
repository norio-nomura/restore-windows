{$} = require 'atom'
crypto = require 'crypto'
fs = require 'fs-plus'
path = require 'path'

module.exports =
  configDefaults:
    regardOperationsAsQuitWhileMillisecond: 5000

  activate: (state) ->
    @initializeDirectory()
    $(window).on 'beforeunload', => @saveWindow()
    atom.project.on 'projectPath-changed', => @projectPathChanged()
    @restoreWindows()
    @projectPathChanged()

  # stateFiles will be stored in atom.getConfigDirPath()
  initializeDirectory: ->
    @mayBeRestoredPath = path.join(atom.getConfigDirPath(), 'restore-windows', 'mayBeRestored')
    fs.makeTreeSync(@mayBeRestoredPath) unless fs.existsSync(@mayBeRestoredPath)
    @openedPath = path.join(atom.getConfigDirPath(), 'restore-windows', 'opened')
    fs.makeTreeSync(@openedPath) unless fs.existsSync(@openedPath)

  saveWindow: ->
    if @projectPath?
      @removeFromOpened(@projectPath)
      @addToMayBeRestored(@projectPath)
    return true

  projectPathChanged: ->
    @removeFromOpened(@projectPath) if @projectPath?
    @projectPath = atom.project.getPath()
    @addToOpened(@projectPath) if @projectPath?

  hashedFilename: (projectPath = @projectPath) ->
    # ignore hash collisions
    crypto.createHash('md5').update(projectPath).digest('hex')

  addToMayBeRestored: (projectPath = @projectPath) ->
    restoreFilePath = path.join(@mayBeRestoredPath, @hashedFilename(projectPath))
    restoreFile = fs.openSync(restoreFilePath, 'w')
    if restoreFile?
      fs.writeSync(restoreFile, projectPath)
    else
      console.log 'Can not open ' + restoreFilePath

  removeFromMayBeRestored: (projectPath = @projectPath) ->
    fs.unlinkSync(path.join(@mayBeRestoredPath, @hashedFilename(projectPath)))

  addToOpened: (projectPath = @projectPath) ->
    openedFilePath = path.join(@openedPath, @hashedFilename(projectPath))
    openedFile = fs.openSync(openedFilePath, 'w')

    if openedFile?
      fs.writeSync(openedFile, projectPath)
    else
      console.log 'Can not open ' + openedFilePath

  removeFromOpened: (projectPath = @projectPath) ->
    fs.unlinkSync(path.join(@openedPath, @hashedFilename(projectPath)))

  restoreWindows: ->
    if fs.readdirSync(@openedPath)?.length == 0
      latestTimestamp = 0
      timestamps = {}
      for file in fs.readdirSync(@mayBeRestoredPath)
        restoreFilePath = path.join(@mayBeRestoredPath, file)
        projectPath = fs.readFileSync(restoreFilePath, encoding = 'utf8')
        timestamp = fs.statSync(restoreFilePath).mtime
        timestamp++
        timestamps[projectPath] = timestamp
        latestTimestamp = timestamp if timestamp > latestTimestamp
        fs.unlinkSync(restoreFilePath)

      pathsToOpenToOpen = []
      threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
      for projectPath, timestamp of timestamps
        if latestTimestamp - timestamp < threshold
          pathsToOpenToOpen.push(projectPath)

      atom.open({pathsToOpen: pathsToOpenToOpen}) if pathsToOpenToOpen.length > 0
      atom.close() unless atom.project.getPath()?

    else
      console.log 'Did not restore because `openedPath` is not empty.'
