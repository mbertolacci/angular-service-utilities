describe 'angular-service-utilities', () ->
    beforeEach module('serviceUtilities')

    beforeEach(module ($exceptionHandlerProvider) ->
        $exceptionHandlerProvider.mode 'log'
    )

    describe '$compose', () ->
        $compose = null
        $rootScope = null
        $exceptionHandler = null

        beforeEach(inject (_$rootScope_, _$compose_, _$exceptionHandler_) ->
            $rootScope = _$rootScope_
            $compose = _$compose_
            $exceptionHandler = _$exceptionHandler_
            jasmine.Clock.useMock()
        )

        it 'should $compose.compose scopes after bidirectionally transmit digests', () ->
            $scope1 = $rootScope.$new(true)
            $scope2 = $rootScope.$new(true)

            $scope2.safe = 'as houses'

            $compose.compose $scope2, $scope1, 'other'

            watchSpyRoot = jasmine.createSpy 'watchSpyRoot'

            watchSpy1 = jasmine.createSpy 'watchSpy1'
            watchPropertySpy1 = jasmine.createSpy 'watchPropertySpy1'

            watchSpy2 = jasmine.createSpy 'watchSpy2'
            watchPropertySpy2 = jasmine.createSpy 'watchPropertySpy2'

            $rootScope.$watch watchSpyRoot

            $scope1.$watch 'other.safe', watchPropertySpy1
            $scope1.$watch watchSpy1
            $scope2.$watch watchSpy2
            $scope2.$watch 'safe', watchPropertySpy2

            # Just composing should trigger changes
            jasmine.Clock.tick(1)

            # None of this needs to trigger a rootScope digest
            expect(watchSpyRoot).not.toHaveBeenCalled()
            # Called once for initial change
            expect(watchPropertySpy1.calls.length).toEqual 1

            # Called once for initialisation, once for triggered digest
            expect(watchSpy1.calls.length).toEqual 2

            expect(watchSpy2).not.toHaveBeenCalled()
            expect(watchPropertySpy2).not.toHaveBeenCalled()

            expect($scope1.other).toEqual $scope2
            expect($scope2.safe).toEqual $scope1.other.safe

            # Manually trigger watchers on second scope
            $scope2.$digest()
            jasmine.Clock.tick(1)

            watchSpyRoot.reset()
            watchSpy1.reset()
            watchSpy2.reset()
            watchPropertySpy1.reset()
            watchPropertySpy2.reset()

            $scope1.other.safe = 'as trousers'
            # Digest after a change should trigger changes
            $scope1.$digest()
            jasmine.Clock.tick(1)

            # None of this needs to trigger a rootScope digest
            expect(watchSpyRoot).not.toHaveBeenCalled()

            expect(watchPropertySpy1).toHaveBeenCalled()
            expect(watchSpy1).toHaveBeenCalled()

            expect(watchSpy2).toHaveBeenCalled()
            expect(watchPropertySpy2).toHaveBeenCalled()

            expect($scope1.other).toEqual $scope2
            expect($scope2.safe).toEqual $scope1.other.safe

            watchSpyRoot.reset()
            watchSpy1.reset()
            watchSpy2.reset()
            watchPropertySpy1.reset()
            watchPropertySpy2.reset()

            jasmine.Clock.tick(1)

            expect(watchPropertySpy1).not.toHaveBeenCalled()
            expect(watchSpy1).not.toHaveBeenCalled()

            expect(watchSpy2).not.toHaveBeenCalled()
            expect(watchPropertySpy2).not.toHaveBeenCalled()



        it 'should $compose.composeProperty after bidirectionally transmit digests', () ->
            $scope1 = $rootScope.$new(true)
            $scope2 = $rootScope.$new(true)

            $scope2.safe = 'as houses'

            $compose.composeProperty $scope2, 'safe', $scope1, 'safe'

            watchSpyRoot = jasmine.createSpy 'watchSpyRoot'
            watchPropertySpy1 = jasmine.createSpy 'watchPropertySpy1'
            watchPropertySpy2 = jasmine.createSpy 'watchPropertySpy2'

            $rootScope.$watch watchSpyRoot
            $scope1.$watch 'safe', watchPropertySpy1
            $scope2.$watch 'safe', watchPropertySpy2

            jasmine.Clock.tick 1

            expect(watchSpyRoot).not.toHaveBeenCalled()
            expect(watchPropertySpy1).toHaveBeenCalled()
            expect(watchPropertySpy2).not.toHaveBeenCalled()

            expect($scope1.safe).toEqual $scope2.safe

            watchSpyRoot.reset()
            watchPropertySpy1.reset()
            watchPropertySpy2.reset()

            $scope1.safe = 'as trousers'
            $scope1.$digest()
            jasmine.Clock.tick 1

            expect(watchSpyRoot).not.toHaveBeenCalled()
            expect(watchPropertySpy1).toHaveBeenCalled()
            expect(watchPropertySpy2).toHaveBeenCalled()

            watchSpyRoot.reset()
            watchPropertySpy1.reset()
            watchPropertySpy2.reset()

            $scope1.safe = 'as grousers'
            $scope1.$digest()
            jasmine.Clock.tick 1

            expect(watchSpyRoot).not.toHaveBeenCalled()
            expect(watchPropertySpy1).toHaveBeenCalled()
            expect(watchPropertySpy2).toHaveBeenCalled()

            watchSpyRoot.reset()
            watchPropertySpy1.reset()
            watchPropertySpy2.reset()

            jasmine.Clock.tick 1

            expect(watchSpyRoot).not.toHaveBeenCalled()
            expect(watchPropertySpy1).not.toHaveBeenCalled()
            expect(watchPropertySpy2).not.toHaveBeenCalled()


        it 'should remove watchers when one of the scopes is destroyed', () ->
            $parentScope = $rootScope.$new()
            $scope = $rootScope.$new()

            $compose.compose $scope, $parentScope, 'child'

            watchParentSpy = jasmine.createSpy 'watchParentSpy'
            watchSpy = jasmine.createSpy 'watchSpy'

            $parentScope.$watch watchParentSpy
            $parentScope.$watch watchSpy
            # Skip through initialisation of watchers
            jasmine.Clock.tick 1
            watchParentSpy.reset()
            watchSpy.reset()

            $scope.$destroy()

            expect($parentScope.child).toBeUndefined()

            $scope.name = "something"
            $scope.$digest()

            expect(watchSpy).not.toHaveBeenCalled()
            expect(watchParentSpy).not.toHaveBeenCalled()

        it 'should fire an error when a composed scope is totally overwritten', () ->
            $parentScope = $rootScope.$new()
            $scope = $rootScope.$new()

            $compose.compose $scope, $parentScope, 'child'

            watchParentSpy = jasmine.createSpy 'watchParentSpy'
            watchSpy = jasmine.createSpy 'watchSpy'

            $parentScope.$watch watchParentSpy
            $parentScope.$watch watchSpy

            jasmine.Clock.tick 1
            watchParentSpy.reset()
            watchSpy.reset()

            $parentScope.child = null

            $parentScope.$digest()

            expect($exceptionHandler.errors.length).toBe 1

    describe '$serviceScope', () ->
        $serviceScope = null

        beforeEach(inject (_$serviceScope_) ->
            $serviceScope = _$serviceScope_
        )

        it 'should correctly $update when the types are different', () ->
            $scope = $serviceScope()

            $scope.$update 'abc', 123
            expect($scope.abc).toBe 123

            $scope.$update 'abc', 'hello'
            expect($scope.abc).toBe 'hello'

            $scope.$update 'abc', { a: 'b' }
            expect($scope.abc).toEqual { a: 'b' }

            $scope.$update 'abc', [1, 2, 3]
            expect($scope.abc).toEqual [1, 2, 3]

            $scope.$update 'abc', null
            expect($scope.abc).toBe null

        it 'should merge two objects without replacing the original one', () ->
            $scope = $serviceScope()

            ab = { a: 'b' }
            $scope.abc = ab
            $scope.$update 'abc', { a: 'c', b: 'd' }

            # Ensure the update happened
            expect($scope.abc).toEqual { a: 'c', b: 'd' }
            # Ensure it's still the original object
            expect($scope.abc).toBe ab

        it 'should merge two arrays without replacing the original one', () ->
            $scope = $serviceScope()

            orig = [1, 2, 3]
            $scope.abc = orig
            $scope.$update 'abc', [4, 5, 6]

            # Ensure the update happened
            expect($scope.abc).toEqual [4, 5, 6]
            # Ensure it's still the original object
            expect($scope.abc).toBe orig

        it 'should merge deep properties of objects', () ->
            $scope = $serviceScope()
            orig = { a: { b: 'c' }}
            $scope.abc = orig
            $scope.$update 'abc', { a: { b: 'd', c: 'e' }}
            expect($scope.abc).toEqual { a: { b: 'd', c: 'e' }}
            expect($scope.abc).toBe orig
            expect($scope.abc.a).toBe orig.a

