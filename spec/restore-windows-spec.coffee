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
    projectsPaths = (path.join projectsBase, num.toString() for num in [0..100])

    beforeEach ->
      for projectPath in projectsPaths
        fs.makeTreeSync projectPath unless fs.existsSync projectPath

    afterEach ->
      for projectPath in projectsPaths
        fs.rmdirSync projectPath if fs.existsSync projectPath

    describe "add/retrieve project path to/from 'restore-windows/opened'", ->

    describe "add/retrieve project path to/from 'restore-windows/mayBeRestored'", ->
      pathsToReopen = []

      beforeEach ->
        for projectPath in projectsPaths
          RestoreWindows.addToMayBeRestored projectPath

        pathsToReopen = RestoreWindows.getPathsToReopen()

      it "all added projects may be restored.", ->
        expect(pathsToReopen.length).toEqual(projectsPaths.length)
        for pathToReopen in pathsToReopen
          expect(projectsPaths).toContain(pathToReopen)

      it "after restoration, mayBeRestored will be empty.", ->
        expect(fs.readdirSync(mayBeRestoredPath).length).toEqual(0)
