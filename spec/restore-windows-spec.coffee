fs = require 'fs-plus'
path = require 'path'

RestoreWindows = require '../lib/restore-windows.coffee'

describe "RestoreWindows", ->
  fixturePath = path.join __dirname, 'fixture'

  beforeEach ->
    fs.makeTreeSync unless fs.existsSync fixturePath

  afterEach ->

  describe "sets initialize directory", ->
    beforeEach ->
      RestoreWindows.initializeDirectory fixturePath

    it "create 'restore-windows'", ->
      expect(fs.existsSync(path.join(fixturePath, 'restore-windows'))).toBeTruthy()

    it "create 'restore-windows/mayBeRestored'", ->
      expect(fs.existsSync(path.join(fixturePath, 'restore-windows', 'mayBeRestored'))).toBeTruthy()

    it "create 'restore-windows/opened'", ->
      expect(fs.existsSync(path.join(fixturePath, 'restore-windows', 'opened'))).toBeTruthy()
