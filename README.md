# serviceScope

serviceScope is an AngularJS utility for bringing two-way data binding into services.

In a nut-shell, it provides a variant of an Angular Scope that can be used to
enscapsulate the interface of your service, much like Scope encapsulates the
interface between controllers and templates.

## Usage and API

Import the JS file and add serviceScope as a module dependency to your module. Within each service that you want to use it in, import $serviceScope.

***Important note: $serviceScopes are just regular Scope objects with some extra tooling, so you can also call $emit, $broadcast, $on, and all the other scopy goodies.***

### Initialisation

Just do this in your service:

```javascript
angular.module('example').factory('exampleService', function($serviceScope) {
    var $scope = $serviceScope();

    // Use like a normal $scope...
    $scope.stuff = 'the stuff';

    return $scope;
});
```

### $attach($scope, name)

Attach the service scope to another scope at $scope[name] with two-way binding. You can attach to as many scopes as you like.

The two-way binding will clean up after itself if either the service scope of the scope it is attached to is destroyed.

In a controller:

```javascript
 angular.module('example').controller('exampleController', function($scope, exampleService) {
 	// Attach at $scope.myFavouriteService
 	exampleService.$attach($scope, 'myFavouriteService');

 	// Now anything attached to exampleService is available at $scope.
 	// myFavouriteService, and any changes triggered either in the 
 	// service or on $scope will propagate
});
```

In a service:

```javascript
angular.module('example').factory('anotherExampleService', function($serviceScope, exampleService) {
 	var $scope = $serviceScope();

 	// Can also attach to other serviceScopes
 	exampleService.$attach($scope, 'myFavouriteService');
});
```

### $attachProperty(property, $scope, name)

Attaches the property at $serviceScope[property] to $scope[name] with two-way data binding. Like $attach, also cleans up after itself if something is destroyed.

Useful when composing services or when you don't want to export an entire service to the view:

```javascript
 angular.module('example').controller('exampleController', function($scope, exampleService) {
 	// Attach exampleService.stuff to $scope.stuffFromService
 	exampleService.$attachProperty('stuff', $scope, 'stuffFromService');

 	// Now changes to $scope.stuffFromService propagate back to the
 	// service and vice-versa
});
```

### $update(property, value)

Used to update $scope[property] to value without necessarily totally overwriting the original reference. It is intended for merging large data structures into a value in a way that avoids triggering the watchers for objects that really didn't change.

This is like angular.copy, except it

  1. Deals with type changes (totally overwrites the original object)
  2. Preserves $ and $$ annotations made by directives such as ngRepeat so the views can do the minimum DOM change possible - with angular.copy.

For example:

```javascript
angular.module('todo').factory('toDoList', function($serviceScope) {
	var $scope = $serviceScope();

	$scope.user = {
		name: 'Johnathan',
		todos: ['Write Gulliver's Travels', 'Eat breakfast']
	};

    $http('...').then(function(result) {
    	// result = {
    	//	 name: 'Johnathan',
    	//   todos: ['Write Gulliver's Travels', 'Eat breakfast', 'Write another essay']
    	// }

    	// $scope.user will now contain the updates value, but
    	// it won't be an entirely new object, and neither will
    	// $scope.user.todos
    	$scope.$update('user', result);
    });

    return $scope;
});
```

This is functionally equivalent to `$scope.user = result`, but if a view was rendering the list of todos using ngRepeat Angular will be able to recycle some of the existing elements instead of having to redraw entirely new ones.

### $defer(name)

Returns a deferred that, when resolved with deferred.resolve(value), will set $scope[name] = value

The promises created can be retrieved with $get(name)

Example:

```javascript
angular.module('todo').factory('toDoList', function($serviceScope) {
	var $scope = $serviceScope();

	var todoDeferred = $scope.defer('todos');

	$http('...').then(function(result) {
		todoDeferred.resolve(result);

		// Now $scope.todos = result
	});

	return $scope;
});
```

After it's initially been resolved, any changes can just be made by setting $scope[name] again.

### $get(name)

Return a promise that will be resolved when the deferred created with $defer(name) is resolved.

Additionally, this promise will always return the latest value for $scope[name], just in case it has later been overwritten.

## Background: what problem does this solve?

AngularJS provides a very elegant system for two-way data binding between
controllers and views, but linking that back in to services in a manner that
respects the Angular philosophy is a non-trivial problem.

This is important because services provide a way to get global state in your application without creating global variables. For instance, if your AngularJS application needs an ORM, services are the place to put it. In other words, services escapsulate the M in your MVC design.

Below are some of the problems you might encounter if you try to use services.

### Problem: propagating data changes without triggering all the watchers on the page

The Angular docs advocate calling $rootScope.$apply whenever something external to Angular should trigger a change. This works because triggering a digest on the $rootScope will cause all other scopes in the application to digest as well.

But, depending on how complex your application is, this might be bad for performance.

**With $serviceScope, a digest will just trigger watchers on the service scope itself and any scopes it is attached to.**

### Problem: notifying services of data changes

If you have an application that, for instance, synchronises the state of the application with a server, and you want to encapsulate that functionality in a service so it persists between controllers, then you probably need two-way data binding between services and views.

The problem is that in Angular there are only two ways to notify a service of a change:

 - Call $rootScope.$watch without a property name so every digest triggers a listener; this might have negative performance considerations
 - Create a function on the service that the controller should call when anything changes. But this kind of boilerplate is the reason so many of us switches to Angular from Backbone (or whatever) in the first place.

**With $serviceScope, the service itself can set a $watch function on one of its properties.**

### Problem: updating data that was delivered with a promise

Promises are the correct Angular-ish way to encapsulate delivering data that's not yet available, but if you need to republish updates that you delivered with a promise it can be quite finnicky.

You might try to do this:

```javascript
// Service
angular.module('example').factory('todo', function($q, $http) {
    var toDoListDeferred = $q.defer();

    $http('...').then(function(result) {
    	// Eg, ['Read a book', 'Eat dinner'];
    	toDoListDeferred.resolve(result);
    });

    var service = {
    	list: toDoListDeferred.promise
    };

    return service;
});

// Controller
angular.module('example').controller('mainController', function($scope, todo) {
	$scope.todo = todo;

	todo.list.then(function() {
		// ... do something important ...
		});
});

// View: the view will render the list once it updates, but the service
// won't be able to see any changes to the data
<div ng-repeat="toDo in todo.list">
    <input type="text" ng-model="toDo" />
</div>
```

This will have two problems:
 
   1. The service doesn't get notified of changes to todoList caused by the controller or the view
   2. If you overwrite service.list in order to push updates back out of the service then service.list will no longer be a promise, so the controller will need to check whether it is a promise before using it.

**With $serviceScope, you can use $defer and $get to deliver a promised based API, whilst still getting two-way data binding.**

Example:

```javascript
angular.module('example').factory('todo', function($serviceScope) {
	var $scope = $serviceScope();

	var toDoListDeferred = $scope.$defer('list');

    $http('...').then(function(result) {
    	// Eg, ['Read a book', 'Eat dinner'];
    	toDoListDeferred.resolve(result);

    	// Now $scope.list contains the result
    });

    return $scope;
});

// Controller
angular.module('example').controller('mainController', function($scope, todo) {
	// Two-way bind todo.list to $scope.todoList
	todo.$attachProperty('list', $scope, 'todoList');
    
	$scope.$get('list').then(function(value) {
   	 	// value is equal to $scope.list

		// ... do something important ...
		});
});

// View: the view will render the list once it updates, but the service
// won't be able to see any changes to the data
<div ng-repeat="toDo in toDoList">
    <input type="text" ng-model="toDo" />
</div>
```


### Problem: composing services with granularity

You may want one service that composes a variety of other services and exports them with a new interface.

For example, you may have an authentication service and a service that talks to MongoDB, and you want to unify them in a service that understands your business logic.

```javascript
angular.module('todo').factory('mongoCollection', function($serviceScope) {
	return function(collectionName) {
    	var $scope = $serviceScope();

    	var valueDeferred = $scope.$defer('value');

    	// Provide two way binding between external MongoDB data store
    	// and $scope.value
    	//
    	// At some stage, calls valueDeferred.resolve(...)

		return $scope;
	};
});
angular.module('todo').factory('authentication', function($serviceScope) {
	var $scope = $serviceScope();

	$scope.currentUser = null;
	$scope.createUser = function() { /* .. */ };
	$scope.login = function() {
		// Can trigger events on scopes
		$scope.$emit('logged-in');
		$scope.currentUser = ...;
	};
	$scope.logout = function() { /* ... */ };


	return $scope;
});

// Todo list
angular.module('todo').factory('todo', function($serviceScope, mongo, authentication) {
	var $scope = $serviceScope();

	// Bind mongo.value to $scope.list
	mongo.$attachProperty('value', $scope, 'list');

	mongo.$get('value').then(function() {
		// Data became available; do something
	});

	// Bind $scope.user to authentication.currentUser
	authentication.$attachProperty('currentUser', $scope, 'user');

	authentication.$on('logged-in', function() {
		// Can listen for events on composed scopes
	});

	// Public API of todo contains list and user which actually come from
	// the other two modules
	return $scope;
});
```



## Usage


