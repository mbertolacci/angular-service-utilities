files = [
  JASMINE,
  JASMINE_ADAPTER,
  'test/lib/angular.js',
  'test/lib/angular-mocks.js',
  'angular-service-utilities.js',
  'test/*.js'
];

autoWatch = true;

browsers = ['PhantomJS'];

junitReporter = {
  outputFile: 'test_out/unit.xml',
  suite: 'unit'
};