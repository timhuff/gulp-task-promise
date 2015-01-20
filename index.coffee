Promise = require 'bluebird'
require 'colors'

#storage for tasks
_tasks = {}
#scope gulp
_gulp = null

#check if object is a promise via ducktyping
isPromise = (input)-> input && typeof input.then == 'function'
#check if object is a promise via ducktyping
isStream = (input)-> input && typeof input.pipe == 'function'

#helper function for humanizing the result of process.hrtime()
humanizeTime = (timeArray)->
	f=(n)->Math.floor(n)%1000;
	[s,m] = timeArray
	#generate time array
	suffix = [' s', ' ms', ' μs', ' ns']
	time = s+(m/1000000000)
	limit = 1
	ndx = 0
	while time < limit
		time *= 1000
		ndx++
	numDecimals = Math.max(0, 4-(parseInt(time)+'').length)
	time.toFixed(numDecimals)+suffix[ndx]

#creates a promise that resolves when a stream has ended
streamToPromise = (stream)-> new Promise (resolve, reject)->
	stream.on 'error', reject
	for success in ['drain', 'finish', 'end', 'close',]
		stream.on success, resolve

#the main task registration method
_task = (name, cb)->
	_tasks[name] = cb
	if _gulp?
		_gulp.task name, -> _task.run(name)

#execute task and promisify the return value
executeTask = (task)->
		returnVal = task.apply(null)
		if isPromise returnVal
			promise = returnVal
		else if isStream returnVal
			promise = streamToPromise returnVal
		else
			promise = Promise.resolve returnVal
		promise

#console.log tag
tag = "[#{"task".yellow}]"

#execute a previously registered task
_task.run = (name)->
	if typeof name == "string"
		#lookup registered task
		task = _tasks[name]
		if !task?
			throw new Error "Task Not Found: '#{name}'"
	#anonymous function support
	else if typeof name == "function"
		task = name
		name = null
	else
		throw new Error 'task.run expects either the name of a task registered with task or an anonymous function'

	startTime = process.hrtime()
	console.log "#{tag} Running '#{name.green.bold}'" if name #no error reporting for anonymous tasks

	return executeTask task
	.tap ->
		if name #no error reporting for anonymous functions
			timeDiff = process.hrtime(startTime)
			timeTaken = humanizeTime timeDiff
			console.log "#{tag} Finished '#{name.magenta.bold}' in "+timeTaken.green.bold
	.catch (error)->
		if name #no error reporting for anonymous functions
			if error.reported
				console.log "#{tag} "+"Failed to complete '".red + name.red.bold + "'".red
			else
				console.log "#{tag} "+"Failed to complete '".red + name.red.bold + "': #{error.message}".red
				console.log error.stack
				error.reported = true
		Promise.reject error


#configure gulp to automatically register tasks as gulp tasks
_task.configure = (gulp)->
	_gulp = gulp
	#if there are pre-existing tasks when configure is called, register them
	if gulp
		for name, task of _tasks
			_gulp.task name, -> _task.run(name)

module.exports = _task