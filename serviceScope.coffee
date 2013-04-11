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
	if !angular.isArray(src) and !angular.isObject(src)
		return src
	if angular.isUndefined(dst)
		return src

	# Merge each property
	angular.forEach src, (value, key) ->
		if key.charAt?(0) == '$'
			return
		if (angular.isObject(value) && angular.isObject(dst[key])) or
		 	(angular.isArray(value) && angular.isArray(dst[key]))
			mergeObject value, dst[key]
		else if dst[key] != value
			dst[key] = value

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
digestOnceOnNextTick = ($scope) ->
	if not $scope.$$digestOnceOnNextTick?
		$scope.$$digestOnceOnNextTick = debounce () ->
			$scope.$digest()

	$scope.$$digestOnceOnNextTick()

angular.module('serviceScope').factory '$serviceScope', ['$rootScope', '$q', ($rootScope, $q) ->
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
			deferred = $q.defer()

			promises[name] = deferred.promise.then (actualValue) ->
				$serviceScope[name] = actualValue
				digestOnceOnNextTick $serviceScope

			return deferred

		$serviceScope.$update = (name, value) ->
			$serviceScope[name] = mergeObject value, $serviceScope[name]

		removeWatcherFunctions = []

		$serviceScope.$attachProperty = (property) ->
			return {
				to: ($scope, name) ->
					removeTheirWatcher = $scope.$watch name, () ->
						$serviceScope[property] = mergeObject $scope[name], $serviceScope[property]
						digestOnceOnNextTick $serviceScope

					removeOurWatcher = $serviceScope.$watch property, () ->
						$scope[name] = mergeObject $serviceScope[property], $scope[name]
						digestOnceOnNextTick $scope

					removeWatchers = () ->
						removeTheirWatcher()
						removeOurWatcher()
						removeWatcherFunctions.splice(removeWatcherFunctions.indexOf removeWatchers, 1)

					$scope.$on '$destroy', removeWatchers
					removeWatcherFunctions.push removeWatchers

					$scope[name] = $serviceScope[property]
					return $scope[name]
			}

		$serviceScope.$attach = ($scope, name) ->
			removeTheirWatcher = $scope.$watch name, (newValue, oldValue) ->
				if newValue != oldValue
					# The user has destroyed the reference!
					throw Error('$serviceScope was detached from scope')
					removeWatchers()
				else
					# A change occured; pass it on
					digestOnceOnNextTick $serviceScope

			removeOurWatcher = $serviceScope.$watch () ->
				digestOnceOnNextTick $scope

			removeWatchers = () ->
				removeTheirWatcher()
				removeOurWatcher()
				removeWatcherFunctions.splice(removeWatcherFunctions.indexOf removeWatchers, 1)

			$scope.$on '$destroy', removeWatchers
			removeWatcherFunctions.push removeWatchers

			$scope[name] = $serviceScope

			return $serviceScope

		$serviceScope.$on '$destroy', () ->
			angular.forEach removeWatcherFunctions, (removeWatchers) ->
				removeWatchers()

		return $serviceScope
]