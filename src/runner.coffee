util             = require 'util'
path             = require 'path'
fs               = require 'fs'
minimist         = require 'minimist'
coffee           = require 'coffee-script/register'
_                = require 'underscore'

jasmine          = require './jasmine-loader'
autoTest         = require './auto-test'

# Command Line Options Hash
minimistOpts =
    boolean: [
        "autoTest"
        "coffee"
        "growl"
        "h"
        "help"
        "matchAll"
        "noColor"
        "noStackTrace"
        "verbose"
        "version"
    ]
    string: [
        "m"
        "match"
        "watchFolders"
    ]

    alias:
        match: "m"
        help: "h"

    default:
        autoTest          : false
        coffee            : false
        extensions        : "js"
        growl             : false
        match             : '.'
        matchAll          : false
        noColor           : false
        noStackTrace      : false
        onComplete        : -> return
        specFolders       : []
        verbose           : false
        watchFolders      : []

exitCode = 0

printVersion = ->
    console.log "2.0.0"
    process.exit 0
    return

# hositing not found? Don't know why it's not hoisting these
help = ->
  process.stdout.write """
USAGE: jasmine-node [--color|--noColor] [--verbose] [--coffee] directory

Options:
  --autoTest         - rerun automatically the specs when a file changes
  --watch PATH       - when used with --autoTest, watches the given path(s) and runs all tests if a change is detected
  --noColor          - do not use color coding for output
  -m, --match REGEXP - load only specs containing "REGEXPspec"
  --matchAll         - relax requirement of "spec" in spec file names
  --verbose          - print extra information per each test run
  --growl            - display test run summary in a growl notification (in addition to other outputs)
  --coffee           - load coffee-script which allows execution .coffee files
  --noStackTrace     - suppress the stack trace generated from a test failure
  --version          - show the current version
  -h, --help         - display this help and exit
"""

#  --config NAME VALUE- set a global variable in process.env
  process.exit -1
  return

onExit = ->
    process.removeListener "exit", onExit
    exitCode = 1 if global.jasmineResult?.fail
    process.exit exitCode
    return

# Parse the args out of the command line
parseArgs = ->
    options = minimist process.argv.slice(2), minimistOpts

    # Verify that our commands are valid
    for key of options
        allowed = key in minimistOpts.boolean
        allowed = key in minimistOpts.string or allowed
        # These don't come in via cli, but might programatically
        secretOptions = ['_', 'specFolders', 'extensions', 'onComplete']
        allowed = key in secretOptions or allowed
        unless allowed
            console.warn "#{key} was not a valid option"
            help()

    # If it's not a TTY, no color for you!
    unless process.stdout.isTTY
        options.noColor = true

    if options.version
        printVersion()

    if options.coffee
        options.extensions += "|coffee|litcoffee"

    if options.watchFolders?
        unless _.isArray options.watchFolders
            options.watchFolders = [options.watchFolders]

    if options.h
        help()

    for spec in options._
        if spec.match(/^\/.*/)
            options.specFolders.push spec
        else
            options.specFolders.push path.join(process.cwd(), spec)

    help() if _.isEmpty options.specFolders

    ## Done Parsing Args...jeeeeze
    return options

# Run the specs with the given options hash
runSpecs = (config) ->
    options = _.clone config
    _.defaults options, minimistOpts.default

    # Clean up after the last run
    if _.isArray global.loadedHelpers
        delete global[helper] for helper in global.loadedHelpers
        delete global['loadedHelpers']
    if _.isObject global.savedFunctions
        global[key] = func for key, func of global.savedFunctions
        delete global['savedFunctions']

    # Sanity Check Watch Dirs
    for dir in options.watchFolders
        continue if fs.existsSync dir
        # Uh-oh!
        console.error "Watch path '#{dir}' doesn't exist!"
        return

    # Check to see if all our files exist
    for spec in options.specFolders
        continue if fs.existsSync spec
        # Uh-oh!
        console.error "File: #{spec} is missing."
        return

    if options.autoTest
        options.patterns = ['**/*.js']
        if options.extensions.indexOf("coffee") isnt -1
            options.patterns.push '**/*.coffee'
            options.patterns.push '**/*.litcoffee'

        autoTest.start options.specFolders, options.watchFolders, options.patterns
        return

    process.on "exit", onExit

    for specFolder in options.specFolders
        jasmine.loadHelpersInFolder specFolder,
                                    new RegExp("helpers?\\.(#{options.extensions})$", 'i')
    try
        matcher = ""
        if options.match isnt minimistOpts.default.match
            matcher = options.match
        else if options.matchAll
            matcher = "#{options.match}(#{options.extensions})$"
        else
            matcher = "#{options.match}spec\\.(#{options.extensions})$"

        options.regExpSpec = new RegExp matcher, "i"
    catch error
        console.error "Failed to build spec-matching regex: #{error}"
        process.exit 2

    jasmine.executeSpecsInFolder options

    return

module.exports = {
    defaults: minimistOpts.default
    runSpecs
    parseArgs
}
