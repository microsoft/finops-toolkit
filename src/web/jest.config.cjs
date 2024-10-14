module.exports = {
    setupFilesAfterEnv: ['<rootDir>/setupTests.ts'],
    testEnvironment: 'jest-environment-jsdom', // Correct the environment here
    moduleFileExtensions: ['js', 'jsx', 'ts', 'tsx'],
    transform: {
      '^.+\\.tsx?$': 'ts-jest',
    },
    testMatch: ['**/__tests__/**/*.test.ts?(x)'],
  };
  