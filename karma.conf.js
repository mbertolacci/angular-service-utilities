module.exports = function(config) {
	config.set({
		frameworks: ['jasmine'],

		files: [
			'test/lib/angular.js',
			'test/lib/angular-mocks.js',
			'angular-service-utilities.js',
			'test/*.js'
		],

		autoWatch: true,

		browsers: ['Chrome'],


		reporters: ['progress', 'junit'],

		junitReporter: {
			outputFile: 'test_out/unit.xml',
			suite: 'unit'
		}
	});
};