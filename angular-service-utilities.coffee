
###
Exports

	compose($srcScope, $dstScope, name): 
		Sets $dstScope[name] = $srcScope and sets up two-way data binding.

	composeProperty($srcScope, property, $dstScope, name):
		Sets $dstScope[name] = $srcScope[property] and sets up two-way data binding.
###
angular.module('serviceUtilities', []).factory '$compose', ['$rootScope', ($rootScope) ->
	exports =
		compose: ($srcScope, $dstScope, name) ->
			# If rootScope is the destination scope, any digests will automatically
			# trigger on srcScope
			if $dstScope.$id != $rootScope.$id
				removeTheirWatcher = $dstScope.$watch () ->
					if $srcScope != $dstScope[name]
						# The user has destroyed the reference!
						throw Error('$dstScope was detached from scope')
						removeWatchers()
					else
						# A change occured; pass it on
						if $dstScope.$$digestSource == $srcScope.$id
							return
						digestOnceOnNextTick $srcScope, $dstScope.$id

			removeOurWatcher = $srcScope.$watch () ->
				if $srcScope.$$digestSource == $dstScope.$id ||
				   $srcScope.$$digestSource == $srcScope.$id   # Handles the case where dstScope == rootScope
					return
				digestOnceOnNextTick $dstScope, $srcScope.$id

			removeWatchers = () ->
				removeTheirWatcher?()
				removeOurWatcher()

			removeWatchersAndBreakLink = () ->
				removeWatchers()
				$dstScope[name] = undefined

			$srcScope.$on '$destroy', removeWatchersAndBreakLink
			$dstScope.$on '$destroy', removeWatchersAndBreakLink

			$dstScope[name] = $srcScope

			digestOnceOnNextTick $dstScope, $srcScope.$id

			# Chain API
			return exports

		composeProperty: ($srcScope, property, $dstScope, name) ->
			# If rootScope is the destination scope, any digests will automatically
			# trigger on srcScope
			if $dstScope.$id != $rootScope.$id
				removeTheirWatcher = $dstScope.$watch () ->
					$srcScope[property] = mergeObject $dstScope[name], $srcScope[property]
					if $dstScope.$$digestSource == $srcScope.$id
						return
					digestOnceOnNextTick $srcScope, $dstScope.$id

			removeOurWatcher = $srcScope.$watch () ->
				$dstScope[name] = mergeObject $srcScope[property], $dstScope[name]
				if $srcScope.$$digestSource == $dstScope.$id ||
				    $srcScope.$$digestSource == $srcScope.$id  # Handles the case where dstScope == rootScope
					return
				digestOnceOnNextTick $dstScope, $srcScope.$id

			removeWatchers = () ->
				removeTheirWatcher?()
				removeOurWatcher()

			removeWatchersAndBreakLink = () ->
				removeWatchers()
				$dstScope[name] = undefined

			$srcScope.$on '$destroy', removeWatchersAndBreakLink
			$dstScope.$on '$destroy', removeWatchersAndBreakLink

			$dstScope[name] = $srcScope[property]

			digestOnceOnNextTick $dstScope, $srcScope.$id

			# Chain API
			return exports

]

###
Exports a factory function returning a service scope.
###
angular.module('serviceUtilities').factory '$serviceScope', ['$rootScope', '$serviceQ', '$compose', ($rootScope, $serviceQ, $compose) ->
	() ->
		$serviceScope = $rootScope.$new(true)

		promises = {}

		$serviceScope.$get = (name) ->
			return promises[name].then () ->
				# Ensure that the promise always gives the most up to date
				# data
				return $serviceScope[name]

		$serviceScope.$defer = (name) ->
			# Not a promise; just send it through
			deferred = $serviceQ.defer()

			promises[name] = deferred.promise.then (actualValue) ->
				$serviceScope[name] = actualValue
				digestOnceOnNextTick $serviceScope

			return deferred

		$serviceScope.$update = (name, value) ->
			$serviceScope[name] = mergeObject value, $serviceScope[name]

		# Convenience methods to connect to the $compose modulke
		$serviceScope.$attachProperty = (property, $scope, name) ->
			$compose.composeProperty $serviceScope, property, $scope, name
			return $serviceScope

		$serviceScope.$attach = ($scope, name) ->
			$compose.compose $serviceScope, $scope, name
			return $serviceScope

		return $serviceScope
]

angular.module('serviceUtilities').factory '$serviceQ', ['$exceptionHandler', ($exceptionHandler) ->
	return qFactory (callback) ->
		setTimeout callback, 0
	, $exceptionHandler
]

# Utility function that ensures that multiple calls to a function
# within a single execution context will result in just one call
# on the next tick
debounce = (fn) ->
	timeout = null
	(args...) ->
		context = this
		clearTimeout timeout
		timeout = setTimeout () ->
			timeout = null
			fn.call(context, args...)
		, 0
		return null

# Like angular.copy, but preserves the existing data structure wherever
# possible.
# Does not touch any property beginning with '$', which means that the
# ngRepeat $$ annotations are preserved.
#
# Distinct from angular.extend in that it will delete properties in the
# destionation object that don't have a counterpart in the source
mergeObject = (src, dst) ->
	if src == dst
		return dst

	# Some unmergeable type; send it out
	if (!angular.isArray(src) and !angular.isObject(src)) or (!angular.isArray(dst) and !angular.isObject(dst))
		return src
	if angular.isUndefined(dst)
		return src

	# Merge each property
	angular.forEach src, (value, key) ->
		if key.charAt?(0) == '$'
			return
		dst[key] = mergeObject value, dst[key]

	if angular.isArray(dst) && angular.isArray(src)
		# Resize the destination array to match the source
		dst.length = src.length
	else
		# Delete any properties not in the source
		angular.forEach dst, (value, key) ->
			if key.charAt?(0) == '$'
				return
			if angular.isUndefined src[key]
				delete dst[key]
	return dst

# Ensures that a digest function only gets called once per execution
# context.
digestOnceOnNextTick = ($scope, source) ->
	if not $scope.$$digestOnceOnNextTick?
		$scope.$$digestOnceOnNextTick = debounce (source) ->
			$scope.$$digestSource = source
			$scope.$digest()
			$scope.$$digestSource = null

	$scope.$$digestOnceOnNextTick(source)


###
The following code is copied from AngularJS in order to get promises that
don't trigger $rootScope.$digest on being resolved

(c) 2010-2012 Google, Inc. http://angularjs.org
License: MIT

Constructs a promise manager.

@param {function(function)} nextTick Function for executing functions in the next turn.
@param {function(...*)} exceptionHandler Function into which unexpected exceptions are passed for
debugging purposes.
@returns {object} Promise manager.
###
qFactory = (nextTick, exceptionHandler) ->
	
	###
	@ngdoc
	@name ng.$q#defer
	@methodOf ng.$q
	@description
	Creates a `Deferred` object which represents a task which will finish in the future.
	
	@returns {Deferred} Returns a new instance of deferred.
	###
	
	###
	@ngdoc
	@name ng.$q#reject
	@methodOf ng.$q
	@description
	Creates a promise that is resolved as rejected with the specified `reason`. This api should be
	used to forward rejection in a chain of promises. If you are dealing with the last promise in
	a promise chain, you don't need to worry about it.
	
	When comparing deferreds/promises to the familiar behavior of try/catch/throw, think of
	`reject` as the `throw` keyword in JavaScript. This also means that if you "catch" an error via
	a promise error callback and you want to forward the error to the promise derived from the
	current promise, you have to "rethrow" the error by returning a rejection constructed via
	`reject`.
	
	<pre>
	promiseB = promiseA.then(function(result) {
	// success: do something and resolve promiseB
	//          with the old or a new result
	return result;
	}, function(reason) {
	// error: handle the error if possible and
	//        resolve promiseB with newPromiseOrValue,
	//        otherwise forward the rejection to promiseB
	if (canHandle(reason)) {
	// handle the error and recover
	return newPromiseOrValue;
	}
	return $q.reject(reason);
	});
	</pre>
	
	@param {*} reason Constant, message, exception or an object representing the rejection reason.
	@returns {Promise} Returns a promise that was already resolved as rejected with the `reason`.
	###
	
	###
	@ngdoc
	@name ng.$q#when
	@methodOf ng.$q
	@description
	Wraps an object that might be a value or a (3rd party) then-able promise into a $q promise.
	This is useful when you are dealing with an object that might or might not be a promise, or if
	the promise comes from a source that can't be trusted.
	
	@param {*} value Value or a promise
	@returns {Promise} Returns a single promise that will be resolved with an array of values,
	each value corresponding to the promise at the same index in the `promises` array. If any of
	the promises is resolved with a rejection, this resulting promise will be resolved with the
	same rejection.
	###
	defaultCallback = (value) ->
		value
	defaultErrback = (reason) ->
		reject reason
	
	###
	@ngdoc
	@name ng.$q#all
	@methodOf ng.$q
	@description
	Combines multiple promises into a single promise that is resolved when all of the input
	promises are resolved.
	
	@param {Array.<Promise>} promises An array of promises.
	@returns {Promise} Returns a single promise that will be resolved with an array of values,
	each value corresponding to the promise at the same index in the `promises` array. If any of
	the promises is resolved with a rejection, this resulting promise will be resolved with the
	same rejection.
	###
	all = (promises) ->
		deferred = defer()
		counter = promises.length
		results = []
		if counter
			angular.forEach promises, (promise, index) ->
				ref(promise).then ((value) ->
					return  if index of results
					results[index] = value
					deferred.resolve results  unless --counter
				), (reason) ->
					return  if index of results
					deferred.reject reason


		else
			deferred.resolve results
		deferred.promise
	defer = ->
		pending = []
		value = undefined
		deferred = undefined
		deferred =
			resolve: (val) ->
				if pending
					callbacks = pending
					pending = `undefined`
					value = ref(val)
					if callbacks.length
						nextTick ->
							callback = undefined
							i = 0
							ii = callbacks.length

							while i < ii
								callback = callbacks[i]
								value.then callback[0], callback[1]
								i++


			reject: (reason) ->
				deferred.resolve reject(reason)

			promise:
				then: (callback, errback) ->
					result = defer()
					wrappedCallback = (value) ->
						try
							result.resolve (callback or defaultCallback)(value)
						catch e
							exceptionHandler e
							result.reject e

					wrappedErrback = (reason) ->
						try
							result.resolve (errback or defaultErrback)(reason)
						catch e
							exceptionHandler e
							result.reject e

					if pending
						pending.push [wrappedCallback, wrappedErrback]
					else
						value.then wrappedCallback, wrappedErrback
					result.promise

		deferred

	ref = (value) ->
		return value  if value and value.then
		then: (callback) ->
			result = defer()
			nextTick ->
				result.resolve callback(value)

			result.promise

	reject = (reason) ->
		then: (callback, errback) ->
			result = defer()
			nextTick ->
				result.resolve (errback or defaultErrback)(reason)

			result.promise

	when_ = (value, callback, errback) ->
		result = defer()
		done = undefined
		wrappedCallback = (value) ->
			try
				return (callback or defaultCallback)(value)
			catch e
				exceptionHandler e
				return reject(e)

		wrappedErrback = (reason) ->
			try
				return (errback or defaultErrback)(reason)
			catch e
				exceptionHandler e
				return reject(e)

		nextTick ->
			ref(value).then ((value) ->
				return  if done
				done = true
				result.resolve ref(value).then(wrappedCallback, wrappedErrback)
			), (reason) ->
				return  if done
				done = true
				result.resolve wrappedErrback(reason)


		result.promise

	defer: defer
	reject: reject
	when: when_
	all: all



