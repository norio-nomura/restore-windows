{$} = require 'atom'
crypto = require 'crypto'
fs = require 'fs-plus'
path = require 'path'

module.exports =
  configDefaults:
    regardOperationsAsQuitWhileMillisecond: 5000

  activate: (state) ->
    @initializeDirectory()
    $(window).on 'beforeunload', => @onBeforeUnload()
    atom.project.on 'projectPath-changed', => @projectPathChanged()
    @restoreWindows()
    @projectPathChanged()

  # stateFiles will be stored in atom.getConfigDirPath()
  initializeDirectory: ->
    @mayBeRestoredPath = path.join(atom.getConfigDirPath(), 'restore-windows', 'mayBeRestored')
    fs.makeTreeSync(@mayBeRestoredPath) unless fs.existsSync(@mayBeRestoredPath)
    @openedPath = path.join(atom.getConfigDirPath(), 'restore-windows', 'opened')
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

  removeOutdatedMayBeRestored: ->
    threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
    outdatedTimestamp = Date.now() - threshold
    for file in fs.readdirSync(@mayBeRestoredPath)
      restoreFilePath = path.join(@mayBeRestoredPath, file)
      timestamp = fs.statSync(restoreFilePath).mtime.valueOf()
      if outdatedTimestamp > timestamp
        fs.unlinkSync(restoreFilePath)

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
        timestamp = fs.statSync(restoreFilePath).mtime.valueOf()
        timestamps[projectPath] = timestamp
        latestTimestamp = timestamp if timestamp > latestTimestamp
        fs.unlinkSync(restoreFilePath)

      pathsToReopen = []
      threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
      outdatedTimestamp = latestTimestamp - threshold
      for projectPath, timestamp of timestamps
        if outdatedTimestamp < timestamp and fs.existsSync(projectPath)
          pathsToReopen.push(projectPath)

      if pathsToReopen.length > 0
        atom.open({pathsToOpen: pathsToReopen, newWindow: true})
        atom.close() unless atom.project.getPath()?

    else
      console.log 'Did not restore because `openedPath` is not empty.'
