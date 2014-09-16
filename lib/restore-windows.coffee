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
    fs.writeFileSync(path.join(@mayBeRestoredPath, @hashedFilename(projectPath)), projectPath)

  removeOutdatedMayBeRestored: ->
    threshold = atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond')
    outdatedTimestamp = Date.now() - threshold
    for filename in fs.readdirSync(@mayBeRestoredPath)
      restoreFilePath = path.join(@mayBeRestoredPath, filename)
      if stat = fs.statSyncNoException(restoreFilePath)
        timestamp = stat.mtime.valueOf()
        if outdatedTimestamp > timestamp
          fs.unlinkSync(restoreFilePath)

  addToOpened: (projectPath = @projectPath) ->
    fs.writeFileSync(path.join(@openedPath, @hashedFilename(projectPath)), projectPath)

  removeFromOpened: (projectPath = @projectPath) ->
    fs.unlinkSync(path.join(@openedPath, @hashedFilename(projectPath)))

  restoreWindows: ->
    if fs.readdirSync(@openedPath)?.length == 0
      latestTimestamp = 0
      timestamps = {}
      for filename in fs.readdirSync(@mayBeRestoredPath)
        restoreFilePath = path.join(@mayBeRestoredPath, filename)
        if stat = fs.statSyncNoException(restoreFilePath)
          projectPath = fs.readFileSync(restoreFilePath, encoding = 'utf8')
          timestamp = stat.mtime.valueOf()
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
