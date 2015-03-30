fs = require 'fs-plus'
path = require 'path'

RestoreWindows = require '../lib/restore-windows.coffee'

describe "RestoreWindows", ->
  fixturePath = path.join __dirname, 'fixture'
  restoreWindowsPath = path.join fixturePath, 'restore-windows'
  mayBeRestoredPath = path.join fixturePath, 'restore-windows', 'mayBeRestored'
  openedPath = path.join fixturePath, 'restore-windows', 'opened'

  beforeEach ->
    atom.config.set('restore-windows.regardOperationsAsQuitWhileMillisecond', 5000)
    fs.makeTreeSync unless fs.existsSync fixturePath

  afterEach ->

  describe "sets initialize directory", ->
    beforeEach ->
      RestoreWindows.initializeDirectory fixturePath

    it "create 'restore-windows'", ->
      expect(fs.existsSync(restoreWindowsPath)).toBeTruthy()

    it "create 'restore-windows/mayBeRestored'", ->
      expect(fs.existsSync(mayBeRestoredPath)).toBeTruthy()

    it "create 'restore-windows/opened'", ->
      expect(fs.existsSync(openedPath)).toBeTruthy()

  describe "store info to opened/mayBeRestored", ->
    projectsBase = path.join fixturePath, "projects"
    projectsPaths = ([path.join projectsBase, num.toString()] for num in [0..100])

    beforeEach ->
      for projectPath in projectsPaths
        fs.makeTreeSync projectPath[0] unless fs.existsSync projectPath[0]

    afterEach ->
      for projectPath in projectsPaths
        fs.rmdirSync projectPath[0] if fs.existsSync projectPath[0]

    describe "add/retrieve project path to/from 'restore-windows/opened'", ->
      multipleRootProjectPaths = [0..3]
        .map (num) -> Math.floor(101 * Math.random())
        .map (num) -> path.join projectsBase, num.toString()

      it "add to opened", ->
        RestoreWindows.addToOpened multipleRootProjectPaths
        expect(fs.readdirSync(openedPath).length).toEqual(1)

      it "remove from opened", ->
        RestoreWindows.removeFromOpened multipleRootProjectPaths
        expect(fs.readdirSync(openedPath).length).toEqual(0)

    describe "add/retrieve project path to/from 'restore-windows/mayBeRestored'", ->
      pathsToReopen = []

      beforeEach ->
        for projectPath in projectsPaths
          RestoreWindows.addToMayBeRestored projectPath

        pathsToReopen = RestoreWindows.getPathsToReopen()

      it "all added to projects mayBeRestored.", ->
        expect(pathsToReopen.length).toEqual(projectsPaths.length)
        for pathToReopen in pathsToReopen
          expect(projectsPaths).toContain(pathToReopen)

      it "after restoration, mayBeRestored will be empty.", ->
        expect(fs.readdirSync(mayBeRestoredPath).length).toEqual(0)

    describe "removeOutdatedMayBeRestored.", ->
      pathsToReopen = []
      recentProjectsPaths = ([path.join projectsBase, num.toString()] for num in [50..100])

      beforeEach ->
        for projectPath in projectsPaths
          RestoreWindows.addToMayBeRestored projectPath

        sleep atom.config.get('restore-windows.regardOperationsAsQuitWhileMillisecond') + 1000

        for projectPath in recentProjectsPaths
          RestoreWindows.addToMayBeRestored projectPath

        RestoreWindows.removeOutdatedMayBeRestored()

        pathsToReopen = RestoreWindows.getPathsToReopen()

      it "removeOutdatedMayBeRestored will remove older mayBeRestored.", ->
        expect(pathsToReopen.length).toEqual(recentProjectsPaths.length)
        for pathToReopen in pathsToReopen
          expect(recentProjectsPaths).toContain(pathToReopen)

    describe "add/retrieve multiple root folders to/from 'restore-windows/mayBeRestored'", ->
      pathsToReopen = []

      multipleRootProjectPaths = [0..3]
        .map (num) -> Math.floor(101 * Math.random())
        .map (num) -> path.join projectsBase, num.toString()

      beforeEach ->
        RestoreWindows.addToMayBeRestored multipleRootProjectPaths
        pathsToReopen = RestoreWindows.getPathsToReopen()

      it "multipleRootProjectPaths", ->
        expect(pathsToReopen.length).toEqual(1)
        expect(pathsToReopen).toContain(multipleRootProjectPaths)

sleep = (ms) ->
  start = new Date().getTime()
  continue while new Date().getTime() - start < ms
